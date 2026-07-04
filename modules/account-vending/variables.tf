variable "account_requests" {
  type = map(object({
    email       = string
    ou          = string
    budget_usd  = number
    environment = string
  }))
}

variable "ou_ids" {
  description = "Map of ou shorthand (prod/nonprod/sandbox) to OU ID"
  type        = map(string)
}

variable "org_access_role_name" {
  type = string
}

variable "notification_email" {
  type      = string
  sensitive = true
}

variable "alert_threshold_pct" {
  type = number
}
