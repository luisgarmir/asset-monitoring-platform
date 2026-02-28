output "telemetry_queue_url" {
  value = aws_sqs_queue.telemetry_queue.url
}
output "telemetry_queue_arn" {
  value = aws_sqs_queue.telemetry_queue.arn
}
