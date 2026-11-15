import express, { Request, Response } from "express";
import { getAllTasks, createTask } from "./tasksRepository";
import { isDbHealthy } from "./db";
import { recordTaskCreated } from "./metrics";

const app = express();
app.use(express.json());

function getVersion(): string {
  return process.env.APP_VERSION ?? "dev";
}

app.get("/version", (_req: Request, res: Response) => {
  res.json({ version: getVersion() });
});

app.get("/health", async (_req: Request, res: Response) => {
  const dbUp = await isDbHealthy();

  res.status(dbUp ? 200 : 503).json({
    status: dbUp ? "ok" : "error",
    database: dbUp ? "up" : "down",
    version: getVersion(),
    timestamp: new Date().toISOString(),
  });
});

app.get("/tasks", async (_req: Request, res: Response) => {
  try {
    const tasks = await getAllTasks();
    res.json(tasks);
  } catch (error) {
    console.error("Error al obtener tareas:", error);
    res.status(500).json({ error: "No se pudieron obtener las tareas" });
  }
});

app.post("/tasks", async (req: Request, res: Response) => {
  const { tarea } = req.body ?? {};

  if (typeof tarea !== "string" || tarea.trim() === "") {
    res.status(400).json({ error: "El campo 'tarea' es obligatorio" });
    return;
  }

  try {
    const task = await createTask(tarea.trim());
    recordTaskCreated();
    res.status(201).json(task);
  } catch (error) {
    console.error("Error al crear tarea:", error);
    res.status(500).json({ error: "No se pudo crear la tarea" });
  }
});

export default app;