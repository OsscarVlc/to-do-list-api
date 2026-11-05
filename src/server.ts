import app from "./app";
import { initDb } from "./db";

const PORT = Number(process.env.PORT) || 3000;

async function start(): Promise<void> {
  await initDb();
  console.log("Conectado a la base de datos");

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`To-do list API escuchando en el puerto ${PORT}`);
  });
}

start().catch((error) => {
  console.error("No se pudo iniciar el servidor:", error);
  process.exit(1);
});