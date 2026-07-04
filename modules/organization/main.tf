# If an Organization already exists in this management account, import it:
#   terraform import module.organization.aws_organizations_organization.this <org-id>
resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
  ]
}

# --- Organizational units ---

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# --- Core account: log archive ---

resource "aws_organizations_account" "log_archive" {
  name              = "${var.name_prefix}-log-archive"
  email             = var.log_archive_email
  parent_id         = aws_organizations_organizational_unit.security.id
  role_name         = var.org_access_role_name
  close_on_deletion = true

  # AWS does not return role_name on read; without this, every plan shows a diff
  lifecycle {
    ignore_changes = [role_name]
  }
}

# --- Service control policies ---

resource "aws_organizations_policy" "deny_root_user" {
  name        = "${var.name_prefix}-deny-root-user"
  description = "Blocks all root user API activity in member accounts"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootUser"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] }
      }
    }]
  })
}

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "${var.name_prefix}-deny-leave-org"
  description = "Member accounts cannot detach themselves from the organization"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeaveOrg"
      Effect   = "Deny"
      Action   = "organizations:LeaveOrganization"
      Resource = "*"
    }]
  })
}

resource "aws_organizations_policy" "region_allowlist" {
  name        = "${var.name_prefix}-region-allowlist"
  description = "Denies activity outside the allowed regions, exempting global services"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyOutsideAllowedRegions"
      Effect = "Deny"
      NotAction = [
        "iam:*",
        "organizations:*",
        "sts:*",
        "account:*",
        "budgets:*",
        "cloudfront:*",
        "route53:*",
        "route53domains:*",
        "support:*",
        "sso:*",
        "identitystore:*",
        "cur:*",
        "waf:*",
        "wafv2:*",
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
      }
    }]
  })
}

resource "aws_organizations_policy" "protect_audit_trail" {
  name        = "${var.name_prefix}-protect-audit-trail"
  description = "Prevents member accounts from tampering with CloudTrail"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ProtectCloudTrail"
      Effect = "Deny"
      Action = [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors",
      ]
      Resource = "*"
    }]
  })
}

# --- Attachments ---
# Guardrails go on OUs, never the root, so the management account stays usable.

locals {
  guarded_ou_ids = {
    security  = aws_organizations_organizational_unit.security.id
    workloads = aws_organizations_organizational_unit.workloads.id
    sandbox   = aws_organizations_organizational_unit.sandbox.id
  }
  region_scoped_ou_ids = {
    workloads = aws_organizations_organizational_unit.workloads.id
    sandbox   = aws_organizations_organizational_unit.sandbox.id
  }
}

resource "aws_organizations_policy_attachment" "deny_root_user" {
  for_each  = local.guarded_ou_ids
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "deny_leave_org" {
  for_each  = local.guarded_ou_ids
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "protect_audit_trail" {
  for_each  = local.guarded_ou_ids
  policy_id = aws_organizations_policy.protect_audit_trail.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "region_allowlist" {
  for_each  = local.region_scoped_ou_ids
  policy_id = aws_organizations_policy.region_allowlist.id
  target_id = each.value
}
