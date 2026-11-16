# to-do-list-api

API de tareas en TypeScript + Express que guarda la información en PostgreSQL (Amazon RDS). La infraestructura se crea con Terraform y todo el ciclo (pruebas, release, deploy y monitoreo) corre en GitHub Actions.


## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/tasks` | Lista todas las tareas |
| `POST` | `/tasks` | Crea una tarea. Body: `{"tarea": "comprar pan"}` |
| `GET` | `/version` | Versión desplegada (variable de ambiente `APP_VERSION`) |
| `GET` | `/health` | Estado de la base de datos, versión y timestamp. Responde `200` si la BD responde y `503` si no |

## Arquitectura

- **EC2** (Ubuntu 24.04, `t3.micro`) con la app corriendo como servicio de systemd en el puerto 3000.
- **RDS PostgreSQL** privada; su Security Group solo acepta conexiones desde el Security Group de la EC2.
- **Secrets Manager** guarda host, usuario y contraseña de la BD. La app los lee al arrancar usando el `LabInstanceProfile`, sin credenciales en el código.
- **CloudWatch**: 3 métricas, 3 alarmas y un dashboard. **SNS** manda las alarmas por correo.
- **HCP Terraform** guarda el `tfstate` (modo de ejecución local).

## Estructura del repositorio

```
to-do-list-api/
├── src/
│   ├── server.ts            arranca la BD y luego el servidor
│   ├── app.ts               rutas de la API
│   ├── tasksRepository.ts   queries de tareas
│   ├── db.ts                pool de conexiones, query() y chequeo de salud
│   ├── secrets.ts           lee las credenciales de Secrets Manager
│   ├── metrics.ts           publica métricas en CloudWatch
│   └── app.test.ts          pruebas unitarias (Jest + supertest)
├── infra/
│   ├── main.tf              EC2, Security Groups, Key Pair, RDS, Secrets Manager
│   ├── monitoring.tf        SNS, alarmas y dashboard
│   ├── variables.tf
│   ├── outputs.tf
│   ├── user_data.sh         instala, compila y arranca la app en el primer boot
│   └── todo-api.pub         llave pública SSH (la privada vive en GitHub Secrets)
├── alerting/
│   ├── alarms.json          definición de las 3 alarmas
│   └── cloudwatch-dashboard.json
├── scripts/
│   └── deploy.sh            se ejecuta en la EC2 para instalar un release
└── .github/workflows/
    ├── deploy-infra.yml     provisionar infraestructura (manual)
    ├── destroy-infra.yml    destruir infraestructura (manual)
    ├── ci.yml               pruebas en cada PR a main
    ├── release.yml          release con zip al empujar un tag v#.#.#
    ├── deploy-app.yml       despliega cada release nuevo en la EC2
    └── health-check.yml     revisa /health cada 5 minutos
```

## Correr el proyecto local

Requisitos: Node.js 22.

```bash
npm install
npm test          # pruebas unitarias (no necesitan AWS ni base de datos)
npm run build     # compila TypeScript a dist/
```

Para arrancar el servidor local se necesita una base de datos y credenciales de AWS con acceso al secreto:

```bash
export DB_SECRET_NAME=todo-api-db-credentials
export AWS_REGION=us-east-1
npm start
```

## Configuración inicial (una sola vez)

1. **HCP Terraform:** crear la organización y el workspace (tipo *CLI-Driven*) con **Execution Mode: Local**. Sus nombres van en el bloque `cloud` de `infra/main.tf`.
2. **Llave SSH:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/todo-api -N ""
   cp ~/.ssh/todo-api.pub infra/todo-api.pub
   ```
3. **GitHub Secrets** (Settings → Secrets and variables → Actions):

| Secret | Valor | ¿Cambia con cada sandbox? |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Learner Lab → AWS Details | Sí |
| `AWS_SECRET_ACCESS_KEY` | Learner Lab → AWS Details | Sí |
| `AWS_SESSION_TOKEN` | Learner Lab → AWS Details | Sí |
| `EC2_HOST` | IP pública de la EC2 (sale al correr Deploy infra) | Sí |
| `TF_API_TOKEN` | Token de usuario de HCP Terraform | No |
| `EC2_SSH_KEY` | Contenido de `~/.ssh/todo-api` | No |
| `RELEASE_TOKEN` | Token *fine-grained* con permiso Contents: Read and write | No |
| `ALERT_EMAIL` | Correo que recibe las alarmas | No |

`RELEASE_TOKEN` es necesario porque los releases creados con el `GITHUB_TOKEN` automático no disparan otros workflows, y el deploy se dispara justamente con el release.

4. **Protección de `main`:** Settings → Branches → requerir PR y que el check `test` pase antes de integrar.

## Crear la infraestructura

1. Iniciar el Learner Lab y actualizar los 3 secrets de AWS.
2. **Actions → Deploy infra → Run workflow.**
3. Confirmar la suscripción de SNS en el correo que llega (se repite en cada deploy porque se crea un tópico nuevo).
4. Copiar la IP del resumen del workflow al secret `EC2_HOST`.
5. Esperar 3 o 4 minutos a que el `user_data` instale la app y probar:
   ```bash
   curl http://<IP>:3000/health
   ```

## Destruir la infraestructura

1. **Actions → Health check → ⋯ → Disable workflow** (si no, falla cada 5 minutos).
2. **Actions → Destroy infra → Run workflow** y escribir `destroy` para confirmar.

No cancelar un `apply` o `destroy` a la mitad: el state puede quedar bloqueado (se libera con **Unlock** en HCP) y los recursos ya creados quedan fuera del state.

## Flujo de cambios

1. Crear una rama, hacer cambios y abrir un PR a `main`. El workflow **CI** compila y corre las pruebas; si fallan, el merge queda bloqueado.
2. Después del merge, crear una versión:
   ```bash
   git checkout main && git pull
   git tag v1.3.0
   git push origin v1.3.0
   ```
3. **Release** corre las pruebas, comprime el repositorio y publica el release con `to-do-list-api-v1.3.0.zip`.
4. **Deploy app** entra a la EC2 por SSH, descarga el zip, instala dependencias, compila, cambia de versión, reinicia el servicio y verifica que `/version` responda el tag nuevo.

## Observabilidad

| Métrica | Origen | Alarma |
|---|---|---|
| `CPUUtilization` (AWS/EC2) | Nativa de AWS | Promedio > 80% durante 2 periodos de 5 min |
| `DbErrors` (TodoApi) | `src/db.ts`: cada error al leer o escribir en RDS | Suma ≥ 1 en 5 min |
| `TasksCreated` (TodoApi) | `src/app.ts`: cada tarea creada | Suma > 50 en 5 min (posible bot o abuso) |

Las métricas propias se publican con `PutMetricDataCommand` de `@aws-sdk/client-cloudwatch` (el equivalente en Node de `put_metric_data` de boto3). Las alarmas y el dashboard se definen en `alerting/` y Terraform los crea en `infra/monitoring.tf`. Las 3 alarmas avisan por correo al entrar en ALARM y al regresar a OK.

Para probar la alarma de RDS: detener la instancia RDS desde la consola y llamar `/health` o `/tasks`; en unos minutos la alarma `todo-api-errores-rds` pasa a ALARM.

El workflow **Health check** usa `schedule` de GitHub Actions, que no garantiza puntualidad: las corridas pueden retrasarse varios minutos. También se puede correr manualmente.