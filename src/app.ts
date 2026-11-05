import express, { Request, Response } from "express";

interface Task {
  id: number;
  tarea: string;
}

const tasks: Task[] = [];
let nextId = 1;

const app = express();
app.use(express.json());

app.get("/tasks", (_req: Request, res: Response) => {
  res.json(tasks);
});

app.post("/tasks", (req: Request, res: Response) => {
  const { tarea } = req.body ?? {};

  if (typeof tarea !== "string" || tarea.trim() === "") {
    res.status(400).json({ error: "El campo 'tarea' es obligatorio" });
    return;
  }

  const task: Task = { id: nextId++, tarea: tarea.trim() };
  tasks.push(task);
  res.status(201).json(task);
});

export default app;