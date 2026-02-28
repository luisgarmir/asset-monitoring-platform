output "lambda_function_name" {
  value = aws_lambda_function.process_telemetry.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.process_telemetry.arn
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.asset_api.api_endpoint
}

output "get_asset_health_url" {
  description = "Full URL to get asset health"
  value       = "${aws_apigatewayv2_api.asset_api.api_endpoint}/assets/{asset_id}/health"
}