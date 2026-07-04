output "account_ids" {
  description = "Account name to account ID"
  value       = { for k, a in aws_organizations_account.this : k => a.id }
}

output "account_arns" {
  value = { for k, a in aws_organizations_account.this : k => a.arn }
}
