# SQS
resource "aws_sqs_queue" "telemetry_dlq" {
  name = "${var.project_name}-telemetry-dlq-${var.env}"

  message_retention_seconds = 172800 # 2 day
}

resource "aws_sqs_queue" "telemetry_queue" {
  name = "${var.project_name}-telemetry-${var.env}"

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.telemetry_dlq.arn
    maxReceiveCount     = 5
  })
}

# Dynamo
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  env          = var.env
}

# get_asset_health Lambda
# IAM role - get_asset_health Lambda
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
        Resource = module.dynamodb.latest_readings_table_arn
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
      DYNAMODB_TABLE = module.dynamodb.latest_readings_table_name
    }
  }
}

# CloudWatch Log Group (explicit creation for retention control)
resource "aws_cloudwatch_log_group" "get_asset_health_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_asset_health.function_name}"
  retention_in_days = 7
}


# HTTP API
resource "aws_apigatewayv2_api" "asset_api" {
  name          = "${var.project_name}-api-${var.env}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

# Lambda integration
resource "aws_apigatewayv2_integration" "get_asset_health_integration" {
  api_id           = aws_apigatewayv2_api.asset_api.id
  integration_type = "AWS_PROXY"

  integration_uri        = aws_lambda_function.get_asset_health.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route: GET /assets/{asset_id}/health
resource "aws_apigatewayv2_route" "get_asset_health_route" {
  api_id    = aws_apigatewayv2_api.asset_api.id
  route_key = "GET /assets/{asset_id}/health"
  target    = "integrations/${aws_apigatewayv2_integration.get_asset_health_integration.id}"
}

# Stage (auto-deploy)
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.asset_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_asset_health.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.asset_api.execution_arn}/*/*"
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-api-${var.env}"
  retention_in_days = 7
}


# Storage
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  env          = var.env
}

# Process Lambda
# IAM role for process_telemetry for lambda
resource "aws_iam_role" "process_telemetry_lambda_role" {
  name = "${var.project_name}-process-telemetry-lambda-role-${var.env}"

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
}

# CloudWatch Logs policy for lambda
resource "aws_iam_role_policy" "process_telemetry_cloudwatch_policy" {
  name = "cloudwatch-logs-policy"
  role = aws_iam_role.process_telemetry_lambda_role.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-process-telemetry-${var.env}:*"
      }
    ]
  })
}

# SQS read/delete policy for lambda
resource "aws_iam_role_policy" "process_telemetry_sqs_policy" {
  name = "sqs-policy"
  role = aws_iam_role.process_telemetry_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.telemetry_queue.arn
      }
    ]
  })
}

# S3 write policy for lambda
resource "aws_iam_role_policy" "process_telemetry_s3_policy" {
  name = "s3-write-policy"
  role = aws_iam_role.process_telemetry_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.storage.bucket_arn}/*"
      }
    ]
  })
}

# DynamoDB write policy (both tables)
resource "aws_iam_role_policy" "process_telemetry_dynamodb_policy" {
  name = "dynamodb-write-policy"
  role = aws_iam_role.process_telemetry_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          module.dynamodb.latest_readings_table_arn,
          module.dynamodb.alerts_table_arn
        ]
      }
    ]
  })
}

# Archive Lambda code
data "archive_file" "process_telemetry_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/process_telemetry"
  output_path = "${path.module}/lambda/process_telemetry.zip"
}

# Lambda function
resource "aws_lambda_function" "process_telemetry" {
  filename         = data.archive_file.process_telemetry_zip.output_path
  function_name    = "${var.project_name}-process-telemetry-${var.env}"
  role             = aws_iam_role.process_telemetry_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.process_telemetry_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      S3_BUCKET      = module.storage.bucket_id
      LATEST_TABLE   = module.dynamodb.latest_readings_table_name
      ALERTS_TABLE   = module.dynamodb.alerts_table_name
      TEMP_THRESHOLD = "80.0"
      VIB_THRESHOLD  = "3.0"
    }
  }
}

# CloudWatch Log Group for lambda
resource "aws_cloudwatch_log_group" "process_telemetry_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_telemetry.function_name}"
  retention_in_days = 7
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = aws_sqs_queue.telemetry_queue.arn
  function_name                      = aws_lambda_function.process_telemetry.arn
  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
}


# IoT
module "iot_core" {
  source = "./modules/iot-core"

  project_name = var.project_name
  env          = var.env
  aws_region    = var.aws_region
  sqs_queue_url = aws_sqs_queue.telemetry_queue.url
  sqs_queue_arn = aws_sqs_queue.telemetry_queue.arn
}