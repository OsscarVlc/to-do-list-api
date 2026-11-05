output "server_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.server.public_ip
}

output "server_instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.server.id
}

output "api_url" {
  description = "URL para probar la API"
  value       = "http://${aws_instance.server.public_ip}:${var.app_port}/tasks"
}

output "db_endpoint" {
  description = "Host de la base de datos RDS"
  value       = aws_db_instance.db.address
}

output "db_secret_name" {
  description = "Nombre del secreto con las credenciales de la BD"
  value       = aws_secretsmanager_secret.db.name
}

output "private_key_pem" {
  description = "Llave privada para entrar por SSH"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}