import request from "supertest";
import app from "./app";
import { createTask } from "./tasksRepository";
import { isDbHealthy } from "./db";
import { recordTaskCreated } from "./metrics";

// Reemplaza los módulos reales por funciones falsas: las pruebas no tocan la BD ni CloudWatch
jest.mock("./tasksRepository");
jest.mock("./db");
jest.mock("./metrics");

const mockedCreateTask = createTask as jest.MockedFunction<typeof createTask>;
const mockedIsDbHealthy = isDbHealthy as jest.MockedFunction<typeof isDbHealthy>;
const mockedRecordTaskCreated = recordTaskCreated as jest.MockedFunction<
  typeof recordTaskCreated
>;

describe("To-do list API", () => {
  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.APP_VERSION;
  });

  test("GET /version regresa la versión de la variable de ambiente", async () => {
    process.env.APP_VERSION = "1.2.3";

    const res = await request(app).get("/version");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ version: "1.2.3" });
  });

  test("POST /tasks crea una tarea, responde 201 y reporta la métrica", async () => {
    mockedCreateTask.mockResolvedValue({ id: 1, tarea: "comprar pan" });

    const res = await request(app)
      .post("/tasks")
      .send({ tarea: "  comprar pan  " });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ id: 1, tarea: "comprar pan" });
    expect(mockedCreateTask).toHaveBeenCalledWith("comprar pan");
    expect(mockedRecordTaskCreated).toHaveBeenCalledTimes(1);
  });

  test("POST /tasks sin 'tarea' responde 400 y no toca la BD", async () => {
    const res = await request(app).post("/tasks").send({});

    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: "El campo 'tarea' es obligatorio" });
    expect(mockedCreateTask).not.toHaveBeenCalled();
  });

  test("GET /health responde 503 cuando la BD está caída", async () => {
    mockedIsDbHealthy.mockResolvedValue(false);
    process.env.APP_VERSION = "v1.2.0";

    const res = await request(app).get("/health");

    expect(res.status).toBe(503);
    expect(res.body).toMatchObject({
      status: "error",
      database: "down",
      version: "v1.2.0",
    });
    expect(typeof res.body.timestamp).toBe("string");
  });
});