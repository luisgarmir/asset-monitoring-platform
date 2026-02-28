variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "enable_point_in_time_recovery" {
  type    = bool
  default = true
}
