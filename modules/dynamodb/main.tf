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

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "alerts" {
  name         = "${var.project_name}-alerts-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "asset_id"
  range_key    = "ts"

  attribute {
    name = "asset_id"
    type = "S"
  }

  attribute {
    name = "ts"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}
