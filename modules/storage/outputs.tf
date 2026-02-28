# aws_s3_bucket.raw_telemetry.arn
# aws_s3_bucket.raw_telemetry.id
output "bucket_id" {
  value = aws_s3_bucket.raw_telemetry.id
}
output "bucket_arn" {
  value = aws_s3_bucket.raw_telemetry.arn
}
