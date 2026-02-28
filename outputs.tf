output "api_endpoint" {
  value = module.api.api_endpoint
}

output "get_asset_health_url" {
  value = module.api.api_url
}
output "iot_endpoint" {
  description = "IoT endpoint for MQTT connection"
  value       = module.iot_core.iot_endpoint
}
