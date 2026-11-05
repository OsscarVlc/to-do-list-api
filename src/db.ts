import { Pool } from "pg";
import { getDbCredentials } from "./secrets";

let pool: Pool | null = null;

// Crea el pool de conexiones y la tabla si no existe.
export async function initDb(): Promise<void> {
  const creds = await getDbCredentials();

  pool = new Pool({
    host: creds.host,
    port: creds.port,
    user: creds.username,
    password: creds.password,
    database: creds.dbname,
    ssl: { rejectUnauthorized: false },
  });

  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      tarea TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

export function getPool(): Pool {
  if (!pool) {
    throw new Error("La base de datos no se ha inicializado (llama initDb primero)");
  }
  return pool;
}