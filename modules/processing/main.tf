# Process Lambda
resource "aws_iam_role" "lambda_role" {
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

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "cloudwatch-logs-policy"
  role = aws_iam_role.lambda_role.id

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

# SQS read/delete policy
resource "aws_iam_role_policy" "sqs_policy" {
  name = "sqs-policy"
  role = aws_iam_role.lambda_role.id

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
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# S3 write policy
resource "aws_iam_role_policy" "s3_policy" {
  name = "s3-write-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

# DynamoDB write policy (both tables)
resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb-write-policy"
  role = aws_iam_role.lambda_role.id

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
          var.latest_table_arn,
          var.alerts_table_arn
        ]
      }
    ]
  })
}

# Archive Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "process_telemetry" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-process-telemetry-${var.env}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      S3_BUCKET      = var.s3_bucket_id
      LATEST_TABLE   = var.latest_table_name
      ALERTS_TABLE   = var.alerts_table_name
      TEMP_THRESHOLD = var.temp_threshold
      VIB_THRESHOLD  = var.vib_threshold
    }
  }
}

# CloudWatch Log Group for lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_telemetry.function_name}"
  retention_in_days = 7
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.process_telemetry.arn
  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
}
