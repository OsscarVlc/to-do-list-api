import express, { Request, Response } from "express";
import { getAllTasks, createTask } from "./tasksRepository";

const app = express();
app.use(express.json());

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
    res.status(201).json(task);
  } catch (error) {
    console.error("Error al crear tarea:", error);
    res.status(500).json({ error: "No se pudo crear la tarea" });
  }
});

export default app;