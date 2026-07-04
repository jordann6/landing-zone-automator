data "aws_caller_identity" "management" {}

module "organization" {
  source = "./modules/organization"

  name_prefix               = var.name_prefix
  allowed_regions           = var.allowed_regions
  service_access_principals = var.service_access_principals
  log_archive_email         = var.log_archive_email
  org_access_role_name      = var.org_access_role_name
}

module "account_vending" {
  source = "./modules/account-vending"

  account_requests     = var.account_requests
  org_access_role_name = var.org_access_role_name
  notification_email   = var.notification_email
  alert_threshold_pct  = var.budget_alert_threshold_pct

  ou_ids = {
    prod    = module.organization.prod_ou_id
    nonprod = module.organization.nonprod_ou_id
    sandbox = module.organization.sandbox_ou_id
  }
}

module "identity_center" {
  source = "./modules/identity-center"
  count  = var.enable_identity_center ? 1 : 0

  name_prefix           = var.name_prefix
  management_account_id = data.aws_caller_identity.management.account_id

  # Developers get nonprod + sandbox accounts; ReadOnly gets every vended account.
  developer_account_ids = [
    for k, a in var.account_requests : module.account_vending.account_ids[k]
    if contains(["nonprod", "sandbox"], a.ou)
  ]
  readonly_account_ids = values(module.account_vending.account_ids)
}

module "log_archive" {
  source = "./modules/log-archive"
  count  = var.phase2_enabled ? 1 : 0

  providers = {
    aws             = aws
    aws.log_archive = aws.log_archive
  }

  name_prefix            = var.name_prefix
  org_id                 = module.organization.org_id
  management_account_id  = data.aws_caller_identity.management.account_id
  log_archive_account_id = module.organization.log_archive_account_id
}

module "baseline_a" {
  source = "./modules/account-baseline"
  count  = var.phase2_enabled && length(var.baseline_targets) > 0 ? 1 : 0

  providers = {
    aws = aws.vended_a
  }

  account_name          = var.baseline_targets[0]
  environment           = var.account_requests[var.baseline_targets[0]].environment
  management_account_id = data.aws_caller_identity.management.account_id
}

module "baseline_b" {
  source = "./modules/account-baseline"
  count  = var.phase2_enabled && length(var.baseline_targets) > 1 ? 1 : 0

  providers = {
    aws = aws.vended_b
  }

  account_name          = var.baseline_targets[1]
  environment           = var.account_requests[var.baseline_targets[1]].environment
  management_account_id = data.aws_caller_identity.management.account_id
}
