import {
  CloudWatchClient,
  PutMetricDataCommand,
  StandardUnit,
} from "@aws-sdk/client-cloudwatch";

// Todas las métricas propias de la app viven en este namespace de CloudWatch
export const METRICS_NAMESPACE = "TodoApi";

const client = new CloudWatchClient({
  region: process.env.AWS_REGION ?? "us-east-1",
});

// Publica un punto de una métrica en CloudWatch.
// Si CloudWatch falla, solo se registra en el log: una métrica nunca debe tumbar un request.
async function putMetric(
  name: string,
  value: number,
  unit: StandardUnit = StandardUnit.Count
): Promise<void> {
  try {
    await client.send(
      new PutMetricDataCommand({
        Namespace: METRICS_NAMESPACE,
        MetricData: [{ MetricName: name, Value: value, Unit: unit }],
      })
    );
  } catch (error) {
    console.error(`No se pudo publicar la métrica ${name}:`, error);
  }
}

// Métrica 2: errores al leer o escribir en RDS
export function recordDbError(): void {
  void putMetric("DbErrors", 1);
}

// Métrica 3: tareas creadas
export function recordTaskCreated(): void {
  void putMetric("TasksCreated", 1);
}