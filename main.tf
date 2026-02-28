# IoT
module "iot_core" {
  source = "./modules/iot-core"

  project_name  = var.project_name
  env           = var.env
  aws_region    = var.aws_region
  sqs_queue_url = module.messaging.telemetry_queue_url
  sqs_queue_arn = module.messaging.telemetry_queue_arn
}

module "messaging" {
  source       = "./modules/messaging"
  project_name = var.project_name
  env          = var.env
}

# Lambda - Processing
module "processing" {
  source = "./modules/processing"

  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region

  sqs_queue_arn     = module.messaging.telemetry_queue_arn
  s3_bucket_id      = module.storage.bucket_id
  s3_bucket_arn     = module.storage.bucket_arn
  latest_table_name = module.dynamodb.latest_readings_table_name
  latest_table_arn  = module.dynamodb.latest_readings_table_arn
  alerts_table_name = module.dynamodb.alerts_table_name
  alerts_table_arn  = module.dynamodb.alerts_table_arn

}

# Storage
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  env          = var.env
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

  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region

  latest_table_name = module.dynamodb.latest_readings_table_name
  latest_table_arn  = module.dynamodb.latest_readings_table_arn
}






