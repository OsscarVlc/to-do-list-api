import { Pool, QueryResultRow } from "pg";
import { getDbCredentials } from "./secrets";
import { recordDbError } from "./metrics";

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
    // Si RDS no responde, fallar rápido en lugar de dejar el request colgado
    connectionTimeoutMillis: 5000,
    query_timeout: 5000,
  });

  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      tarea TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

// Único punto por donde pasan todas las queries: si una falla, se reporta la métrica.
export async function query<T extends QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<T[]> {
  if (!pool) {
    throw new Error("La base de datos no se ha inicializado (llama initDb primero)");
  }

  try {
    const result = await pool.query<T>(text, params);
    return result.rows;
  } catch (error) {
    recordDbError();
    throw error;
  }
}

// Usado por /health: true si la BD responde
export async function isDbHealthy(): Promise<boolean> {
  try {
    await query("SELECT 1");
    return true;
  } catch {
    return false;
  }
}