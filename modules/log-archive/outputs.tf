output "bucket_name" {
  value = aws_s3_bucket.trail.id
}

output "trail_arn" {
  value = aws_cloudtrail.org.arn
}

output "kms_key_arn" {
  value = aws_kms_key.trail.arn
}
