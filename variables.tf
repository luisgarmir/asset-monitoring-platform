variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "asset-monitoring-platform"
}

variable "env" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner/team tag."
  type        = string
  default     = "Luis Garcia"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

locals {
  name_prefix = "${var.project_name}-${var.env}"
}