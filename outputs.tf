output "org_id" {
  description = "AWS Organization ID"
  value       = module.organization.org_id
}

output "ou_ids" {
  description = "Organizational unit IDs"
  value = {
    security = module.organization.security_ou_id
    prod     = module.organization.prod_ou_id
    nonprod  = module.organization.nonprod_ou_id
    sandbox  = module.organization.sandbox_ou_id
  }
}

output "vended_account_ids" {
  description = "Account name to account ID for every vended account"
  value       = module.account_vending.account_ids
  sensitive   = true
}

output "log_archive_account_id" {
  description = "Account ID of the log-archive account"
  value       = module.organization.log_archive_account_id
  sensitive   = true
}

output "log_archive_bucket" {
  description = "S3 bucket receiving the organization CloudTrail"
  value       = var.phase2_enabled ? module.log_archive[0].bucket_name : null
}

output "sso_portal_url" {
  description = "IAM Identity Center access portal for the demo login check"
  value       = var.enable_identity_center ? module.identity_center[0].portal_url : null
}
