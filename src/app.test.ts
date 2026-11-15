import request from "supertest";
import app from "./app";
import { createTask } from "./tasksRepository";

// Reemplaza el repositorio real por funciones falsas: las pruebas no tocan la BD
jest.mock("./tasksRepository");

const mockedCreateTask = createTask as jest.MockedFunction<typeof createTask>;

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

  test("POST /tasks crea una tarea y responde 201", async () => {
    mockedCreateTask.mockResolvedValue({ id: 1, tarea: "comprar pan" });

    const res = await request(app)
      .post("/tasks")
      .send({ tarea: "  comprar pan  " });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ id: 1, tarea: "comprar pan" });
    expect(mockedCreateTask).toHaveBeenCalledWith("comprar pan");
  });

  test("POST /tasks sin 'tarea' responde 400 y no toca la BD", async () => {
    const res = await request(app).post("/tasks").send({});

    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: "El campo 'tarea' es obligatorio" });
    expect(mockedCreateTask).not.toHaveBeenCalled();
  });
});