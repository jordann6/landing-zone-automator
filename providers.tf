provider "aws" {
  region = var.home_region

  default_tags {
    tags = var.tags
  }
}

# The aliased providers below assume the org access role into member accounts.
# Their role ARNs reference account IDs created by this same configuration,
# which is why phase2_enabled gates every resource that uses them: on the
# first apply the accounts (and therefore the ARNs) do not exist yet.

provider "aws" {
  alias  = "log_archive"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${try(module.organization.log_archive_account_id, "000000000000")}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_a"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${try(module.account_vending.account_ids[var.baseline_targets[0]], "000000000000")}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "vended_b"
  region = var.home_region

  assume_role {
    role_arn = "arn:aws:iam::${try(module.account_vending.account_ids[var.baseline_targets[1]], "000000000000")}:role/${var.org_access_role_name}"
  }

  default_tags {
    tags = var.tags
  }
}
