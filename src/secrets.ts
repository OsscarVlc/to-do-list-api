import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

export interface DbCredentials {
  host: string;
  port: number;
  username: string;
  password: string;
  dbname: string;
}

// Lee las credenciales de la BD desde AWS Secrets Manager.
// Los permisos vienen del instance profile de la EC2, no de llaves en el código.
export async function getDbCredentials(): Promise<DbCredentials> {
  const secretName = process.env.DB_SECRET_NAME;
  if (!secretName) {
    throw new Error("Falta la variable de ambiente DB_SECRET_NAME");
  }

  const client = new SecretsManagerClient({
    region: process.env.AWS_REGION ?? "us-east-1",
  });

  const response = await client.send(
    new GetSecretValueCommand({ SecretId: secretName })
  );

  if (!response.SecretString) {
    throw new Error(`El secreto ${secretName} no tiene contenido`);
  }

  return JSON.parse(response.SecretString) as DbCredentials;
}