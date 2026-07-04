locals {
  bucket_name = "${var.name_prefix}-org-trail-${var.log_archive_account_id}"
}

# --- KMS key for the trail (management account) ---

resource "aws_kms_key" "trail" {
  description             = "Encrypts the organization CloudTrail"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ManagementAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.management_account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudTrailEncrypt"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.management_account_id }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "trail" {
  name          = "alias/${var.name_prefix}-org-trail"
  target_key_id = aws_kms_key.trail.key_id
}

# --- Log bucket (log-archive account) ---

resource "aws_s3_bucket" "trail" {
  provider = aws.log_archive

  bucket              = local.bucket_name
  object_lock_enabled = true

  # Demo teardown: retention is 1 day and governance mode, so destroy works
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.trail]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.trail.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.management_account_id }
        }
      },
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${var.management_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = var.management_account_id
          }
        }
      },
      {
        Sid       = "CloudTrailOrgWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${var.org_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = var.management_account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# --- Organization trail (management account) ---

resource "aws_cloudtrail" "org" {
  name                          = "${var.name_prefix}-org-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.trail.arn

  depends_on = [aws_s3_bucket_policy.trail]
}
