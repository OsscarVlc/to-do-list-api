import { getPool } from "./db";

export interface Task {
  id: number;
  tarea: string;
}

export async function getAllTasks(): Promise<Task[]> {
  const result = await getPool().query<Task>(
    "SELECT id, tarea FROM tasks ORDER BY id"
  );
  return result.rows;
}

export async function createTask(tarea: string): Promise<Task> {
  const result = await getPool().query<Task>(
    "INSERT INTO tasks (tarea) VALUES ($1) RETURNING id, tarea",
    [tarea]
  );
  return result.rows[0];
}