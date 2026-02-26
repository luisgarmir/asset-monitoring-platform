# SQS Dead Letter Queue
resource "aws_sqs_queue" "telemetry_dlq" {
  name = "${var.project_name}-telemetry-dlq-${var.env}"

  message_retention_seconds = 172800 # 2 day
}

# SQS Main Queue
resource "aws_sqs_queue" "telemetry_queue" {
  name = "${var.project_name}-telemetry-${var.env}"

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.telemetry_dlq.arn
    maxReceiveCount     = 5
  })
}

# DynamoDB - Latest Readings
resource "aws_dynamodb_table" "latest_readings" {
  name         = "${var.project_name}-latest-readings-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "asset_id"

  attribute {
    name = "asset_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

# IAM role for get_asset_health Lambda
resource "aws_iam_role" "get_asset_health_lambda_role" {
  name = "${var.project_name}-get-asset-health-lambda-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags automatically applied from provider default_tags
}

# CloudWatch Logs policy for Lambda
resource "aws_iam_role_policy" "get_asset_health_cloudwatch_policy" {
  name = "cloudwatch-logs-policy"
  role = aws_iam_role.get_asset_health_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-get-asset-health-${var.env}:*"
      }
    ]
  })
}

# DynamoDB read-only policy for latest_readings table
resource "aws_iam_role_policy" "get_asset_health_dynamodb_policy" {
  name = "dynamodb-read-policy"
  role = aws_iam_role.get_asset_health_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.latest_readings.arn
      }
    ]
  })
}

# Archive Lambda code
data "archive_file" "get_asset_health_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get_asset_health"
  output_path = "${path.module}/lambda/get_asset_health.zip"
}

# Lambda function
resource "aws_lambda_function" "get_asset_health" {
  filename         = data.archive_file.get_asset_health_zip.output_path
  function_name    = "${var.project_name}-get-asset-health-${var.env}"
  role             = aws_iam_role.get_asset_health_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.get_asset_health_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.latest_readings.name
    }
  }
}

# CloudWatch Log Group (explicit creation for retention control)
resource "aws_cloudwatch_log_group" "get_asset_health_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_asset_health.function_name}"
  retention_in_days = 7
}

