output "latest_readings_table_name" {
  value = aws_dynamodb_table.latest_readings.name
}

output "latest_readings_table_arn" {
  value = aws_dynamodb_table.latest_readings.arn
}

output "alerts_table_name" {
  value = aws_dynamodb_table.alerts.name
}

output "alerts_table_arn" {
  value = aws_dynamodb_table.alerts.arn
}
