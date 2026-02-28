variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "latest_table_name" {
  type = string
}

variable "latest_table_arn" {
  type = string
}

variable "alerts_table_name" {
  type = string
}

variable "alerts_table_arn" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "temp_threshold" {
  type    = string
  default = "80.0"
}

variable "vib_threshold" {
  type    = string
  default = "3.0"
}
