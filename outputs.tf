output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.asset_api.api_endpoint
}

output "get_asset_health_url" {
  description = "Full URL to get asset health"
  value       = "${aws_apigatewayv2_api.asset_api.api_endpoint}/assets/{asset_id}/health"
}
output "iot_endpoint" {
  description = "IoT endpoint for MQTT connection"
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

# Device 1 outputs
output "device_1_thing_name" {
  description = "Device 1 Thing name"
  value       = aws_iot_thing.device_1.name
}

# Device 2 outputs
output "device_2_thing_name" {
  description = "Device 2 Thing name"
  value       = aws_iot_thing.device_2.name
}

output "device_3_thing_name" {
  description = "Device 3 Thing name"
  value       = aws_iot_thing.device_3.name
}

