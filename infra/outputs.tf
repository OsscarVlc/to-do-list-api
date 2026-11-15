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

output "db_identifier" {
  description = "Identificador de la instancia RDS (para detenerla en la prueba de la alarma)"
  value       = aws_db_instance.db.identifier
}

output "dashboard_url" {
  description = "Link directo al dashboard de CloudWatch"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}