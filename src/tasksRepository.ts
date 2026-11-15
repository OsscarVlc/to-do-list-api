import { query } from "./db";

export interface Task {
  id: number;
  tarea: string;
}

export async function getAllTasks(): Promise<Task[]> {
  return query<Task>("SELECT id, tarea FROM tasks ORDER BY id");
}

export async function createTask(tarea: string): Promise<Task> {
  const rows = await query<Task>(
    "INSERT INTO tasks (tarea) VALUES ($1) RETURNING id, tarea",
    [tarea]
  );
  return rows[0];
}