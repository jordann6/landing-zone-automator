resource "aws_organizations_account" "this" {
  for_each = var.account_requests

  name              = each.key
  email             = each.value.email
  parent_id         = var.ou_ids[each.value.ou]
  role_name         = var.org_access_role_name
  close_on_deletion = true

  tags = {
    environment = each.value.environment
    cost_center = each.value.environment == "prod" ? "production" : "engineering"
    vended_by   = "landing-zone-automator"
  }

  # AWS does not return role_name on read; without this, every plan shows a diff
  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_budgets_budget" "per_account" {
  for_each = var.account_requests

  name         = "${each.key}-monthly-cap"
  budget_type  = "COST"
  limit_amount = tostring(each.value.budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [aws_organizations_account.this[each.key].id]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.alert_threshold_pct
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.notification_email]
  }
}
