output "lambda_function_name" {
  value = aws_lambda_function.process_telemetry.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.process_telemetry.arn
}
