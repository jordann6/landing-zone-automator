output "org_id" {
  value = aws_organizations_organization.this.id
}

output "root_id" {
  value = aws_organizations_organization.this.roots[0].id
}

output "security_ou_id" {
  value = aws_organizations_organizational_unit.security.id
}

output "prod_ou_id" {
  value = aws_organizations_organizational_unit.prod.id
}

output "nonprod_ou_id" {
  value = aws_organizations_organizational_unit.nonprod.id
}

output "sandbox_ou_id" {
  value = aws_organizations_organizational_unit.sandbox.id
}

output "log_archive_account_id" {
  value = aws_organizations_account.log_archive.id
}
