# Runs inside a vended account via an assumed-role provider passed from root.
# Default VPC deletion is handled by scripts/delete-default-vpc.sh as a deploy
# step, since Terraform has no resource that deletes a default VPC.

resource "aws_iam_account_alias" "this" {
  account_alias = var.account_name
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# Scoped role the validation script assumes to prove the baseline landed
resource "aws_iam_role" "smoke_test" {
  name = "lza-smoke-test"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.management_account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    environment = var.environment
  }
}

resource "aws_iam_role_policy" "smoke_test" {
  name = "lza-smoke-test"
  role = aws_iam_role.smoke_test.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeVpcs", "ec2:DescribeInstances", "sts:GetCallerIdentity"]
      Resource = "*"
    }]
  })
}
