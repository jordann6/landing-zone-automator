output "portal_url" {
  description = "SSO access portal URL derived from the identity store ID"
  value       = "https://${local.identity_store_id}.awsapps.com/start"
}

output "permission_set_arns" {
  value = {
    platform_admin = aws_ssoadmin_permission_set.platform_admin.arn
    developer      = aws_ssoadmin_permission_set.developer.arn
    read_only      = aws_ssoadmin_permission_set.read_only.arn
  }
}
