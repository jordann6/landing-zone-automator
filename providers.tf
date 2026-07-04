provider "aws" {
  region = var.home_region

  default_tags {
    tags = var.tags
  }
}

# The aliased providers assume the org access role into member accounts.
# Provider configurations must be resolvable at plan and import time, so the
# account IDs come from variables (filled by scripts/write-phase2-tfvars.sh
# after stage 1) rather than module outputs. Until then they point at a dummy
# account ID, and phase2_enabled keeps every resource that would use them out
# of the graph.

provider "aws" {
  alias  = "log_archive"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${var.log_archive_account_id}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_a"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${lookup(var.baseline_account_ids, try(var.baseline_targets[0], ""), "000000000000")}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_b"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${lookup(var.baseline_account_ids, try(var.baseline_targets[1], ""), "000000000000")}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}
