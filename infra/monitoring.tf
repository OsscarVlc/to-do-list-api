### Observabilidad: SNS + alarmas + dashboard
### La configuración de alarmas y dashboard vive en la carpeta alerting/ del repo

locals {
  alarms = jsondecode(file("${path.module}/../alerting/alarms.json"))
}

### Tópico SNS: el "canal" al que las alarmas mandan sus avisos
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

### Suscripción por correo (hay que confirmarla desde el correo que llega)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

### Una alarma por cada elemento de alerting/alarms.json
resource "aws_cloudwatch_metric_alarm" "alarms" {
  # La llave es el nombre de la alarma y el valor es su posición en la lista
  for_each = { for index, alarm in local.alarms : alarm.name => index }

  alarm_name          = local.alarms[each.value].name
  alarm_description   = local.alarms[each.value].description
  namespace           = local.alarms[each.value].namespace
  metric_name         = local.alarms[each.value].metric_name
  statistic           = local.alarms[each.value].statistic
  period              = local.alarms[each.value].period
  evaluation_periods  = local.alarms[each.value].evaluation_periods
  threshold           = local.alarms[each.value].threshold
  comparison_operator = local.alarms[each.value].comparison_operator
  treat_missing_data  = local.alarms[each.value].treat_missing_data

  # "EC2_INSTANCE_ID" en el JSON se reemplaza por el ID real de la instancia
  dimensions = {
    for key, value in local.alarms[each.value].dimensions :
    key => value == "EC2_INSTANCE_ID" ? aws_instance.server.id : value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

### Dashboard con las 3 métricas
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = templatefile("${path.module}/../alerting/cloudwatch-dashboard.json", {
    region      = var.region
    instance_id = aws_instance.server.id
  })
}