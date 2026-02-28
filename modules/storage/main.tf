
# S3 Objects Raw Telemetry bucket
resource "aws_s3_bucket" "raw_telemetry" {
  bucket = "${var.project_name}-raw-telemetry-${var.env}"
}

# Enable versioning
resource "aws_s3_bucket_versioning" "raw_telemetry" {
  bucket = aws_s3_bucket.raw_telemetry.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_telemetry" {
  bucket = aws_s3_bucket.raw_telemetry.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "raw_telemetry" {
  bucket = aws_s3_bucket.raw_telemetry.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy (optional - archive old data)
resource "aws_s3_bucket_lifecycle_configuration" "raw_telemetry" {
  bucket = aws_s3_bucket.raw_telemetry.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    filter {
      prefix = "raw/" # Only applies to objects with "raw/" prefix
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}