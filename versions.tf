terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Real values live in backend.hcl (gitignored). Initialize with:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {}
}
