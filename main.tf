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

# API
module "api" {
  source = "./modules/api"
  
  project_name      = var.project_name
  env               = var.env
  aws_region            = var.aws_region

  latest_table_name = module.dynamodb.latest_readings_table_name
  latest_table_arn  = module.dynamodb.latest_readings_table_arn
}

# Storage
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  env          = var.env
}

# Lambda - Processing
module "processing" {
  source = "./modules/processing"

  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region

  sqs_queue_arn     = aws_sqs_queue.telemetry_queue.arn
  s3_bucket_id      = module.storage.bucket_id
  s3_bucket_arn     = module.storage.bucket_arn
  latest_table_name = module.dynamodb.latest_readings_table_name
  latest_table_arn  = module.dynamodb.latest_readings_table_arn
  alerts_table_name = module.dynamodb.alerts_table_name
  alerts_table_arn  = module.dynamodb.alerts_table_arn

}

# IoT
module "iot_core" {
  source = "./modules/iot-core"

  project_name  = var.project_name
  env           = var.env
  aws_region    = var.aws_region
  sqs_queue_url = aws_sqs_queue.telemetry_queue.url
  sqs_queue_arn = aws_sqs_queue.telemetry_queue.arn
}
