provider "aws" {
  region = var.home_region

  default_tags {
    tags = var.tags
  }
}

# The aliased providers assume the org access role into member accounts.
# Terraform configures every declared provider during plan, and provider
# configurations must be resolvable then, so the account IDs come from
# variables (filled by scripts/write-phase2-tfvars.sh after stage 1) rather
# than module outputs, and role_arn collapses to null while phase2_enabled
# is false so the providers configure without assuming anything.

provider "aws" {
  alias  = "log_archive"
  region = var.home_region

  assume_role {
    role_arn = var.phase2_enabled ? "arn:aws:iam::${var.log_archive_account_id}:role/${var.org_access_role_name}" : null
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_a"
  region = var.home_region

  assume_role {
    role_arn = var.phase2_enabled ? "arn:aws:iam::${lookup(var.baseline_account_ids, try(var.baseline_targets[0], ""), "000000000000")}:role/${var.org_access_role_name}" : null
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_b"
  region = var.home_region

  assume_role {
    role_arn = var.phase2_enabled ? "arn:aws:iam::${lookup(var.baseline_account_ids, try(var.baseline_targets[1], ""), "000000000000")}:role/${var.org_access_role_name}" : null
  }

  default_tags {
    tags = var.tags
  }
}
