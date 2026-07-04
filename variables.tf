variable "name_prefix" {
  description = "Short prefix for named resources (buckets, roles, policies)"
  type        = string
  default     = "lza"
}

variable "home_region" {
  description = "Region for the management-account resources (trail, KMS, budgets)"
  type        = string
  default     = "us-east-1"
}

variable "allowed_regions" {
  description = "Regions member accounts may use; everything else is denied by SCP"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "org_access_role_name" {
  description = "Cross-account role AWS creates in vended accounts for the management account"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

# Applying aws_organizations_organization sets trusted service access to
# exactly this list, so when importing an existing org, merge in whatever is
# already enabled (aws organizations list-aws-service-access-for-organization)
# or those integrations get disabled.
variable "service_access_principals" {
  description = "AWS services granted trusted access to the organization"
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
  ]
}

variable "log_archive_email" {
  description = "Unique email for the log-archive account. Set in the gitignored tfvars."
  type        = string
}

variable "notification_email" {
  description = "Email that receives budget alarms. Set in the gitignored tfvars."
  type        = string
  sensitive   = true
}

# Emails must be globally unique across AWS and cannot be reused for 90 days
# after an account closes, so demo names carry a date suffix.
# Not marked sensitive because the map feeds for_each (Terraform forbids
# sensitive for_each values); secrecy comes from the tfvars file being
# gitignored and account IDs being sensitive outputs.
variable "account_requests" {
  description = "Accounts to vend. Key becomes the account name."
  type = map(object({
    email       = string
    ou          = string # one of: prod, nonprod, sandbox
    budget_usd  = number
    environment = string
  }))
  default = {}

  validation {
    condition     = alltrue([for a in var.account_requests : contains(["prod", "nonprod", "sandbox"], a.ou)])
    error_message = "Each account's ou must be prod, nonprod, or sandbox."
  }
}

# Terraform providers cannot be created dynamically per for_each entry, so the
# in-account baseline is applied through statically aliased providers. List the
# account_requests keys (max 2 for the demo) that should receive the baseline.
variable "baseline_targets" {
  description = "account_requests keys to apply the in-account baseline to (max 2)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.baseline_targets) <= 2
    error_message = "The demo supports at most 2 baseline targets."
  }
}

# IAM Identity Center's organization instance can only be enabled in the
# console (the CreateInstance API rejects management accounts). Deploy with
# this false until that one-time click is done, then flip it.
variable "enable_identity_center" {
  description = "Set true once the Identity Center instance is enabled in the console"
  type        = bool
  default     = true
}

# Two-stage apply: the log-archive bucket, org trail, and account baselines
# need to assume roles into member accounts that do not exist until the first
# apply finishes. Run apply with this false, then flip to true and apply again.
variable "phase2_enabled" {
  description = "Enable cross-account resources (log archive, trail, baselines) after the first apply"
  type        = bool
  default     = false
}

variable "budget_alert_threshold_pct" {
  description = "Percent of an account budget at which the email alarm fires"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Tags applied to all taggable resources"
  type        = map(string)
  default = {
    project    = "landing-zone-automator"
    managed_by = "terraform"
  }
}
