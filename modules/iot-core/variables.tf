variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "device_names" {
  type    = list(string)
  default = ["device-1", "device-2", "device-3"]
}

variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}