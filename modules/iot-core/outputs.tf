output "iot_endpoint" {
  value = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "thing_type_name" {
  value = aws_iot_thing_type.motor.name
}

output "policy_name" {
  value = aws_iot_policy.device_policy.name
}

output "thing_names" {
  value = [for thing in aws_iot_thing.device : thing.name]
}

output "thing_arns" {
  value = [for thing in aws_iot_thing.device : thing.arn]
}
