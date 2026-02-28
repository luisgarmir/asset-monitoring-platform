output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.asset_api.api_endpoint
}

output "api_url" {
  description = "Full URL to get asset health"
  value       = "${aws_apigatewayv2_api.asset_api.api_endpoint}/assets/{asset_id}/health"
}