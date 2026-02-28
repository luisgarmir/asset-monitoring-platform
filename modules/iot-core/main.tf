# IoT resources
# Data source for IoT endpoint
data "aws_iot_endpoint" "iot_endpoint" {
  endpoint_type = "iot:Data-ATS"
}

# IAM role for IoT Rule
resource "aws_iam_role" "iot_rule_role" {
  name = "${var.project_name}-iot-rule-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# SQS write policy for IoT Rule
resource "aws_iam_role_policy" "iot_rule_sqs_policy" {
  name = "sqs-write-policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# IoT Topic Rule
resource "aws_iot_topic_rule" "telemetry_rule" {
  name        = "${replace(var.project_name, "-", "_")}_telemetry_rule_${var.env}"
  description = "Route telemetry messages to SQS"
  enabled     = true
  sql         = "SELECT * FROM 'telemetry/#'"
  sql_version = "2016-03-23"

  # Update reference to SQS
  sqs {
    queue_url  = var.sqs_queue_url
    role_arn   = aws_iam_role.iot_rule_role.arn
    use_base64 = false
  }
}



# Thing Type (optional, for organization)
resource "aws_iot_thing_type" "motor" {
  name = "${var.project_name}-motor-${var.env}"

  properties {
    description           = "Industrial motor sensors"
    searchable_attributes = ["manufacturer", "model", "location"]
  }
}

# IoT Policy (shared across all devices)
resource "aws_iot_policy" "device_policy" {
  name = "${var.project_name}-device-policy-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:*:client/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:*:topic/telemetry/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:*:topicfilter/telemetry/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:*:topic/telemetry/*"
      }
    ]
  })
}

resource "aws_iot_thing" "device" {
  for_each = toset(var.device_names)

  name            = "${var.project_name}-${each.value}-${var.env}"
  thing_type_name = aws_iot_thing_type.motor.name

  attributes = {
    manufacturer = "test"
    model        = "v1"
    location     = "lab"
  }
}