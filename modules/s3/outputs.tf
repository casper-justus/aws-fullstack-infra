output "bucket_name" {
  value = aws_s3_bucket.app_assets.bucket
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.app_assets.arn
}

output "logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
