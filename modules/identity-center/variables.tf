variable "name_prefix" {
  type = string
}

variable "management_account_id" {
  type = string
}

variable "developer_account_ids" {
  description = "Accounts the Developers group can access"
  type        = list(string)
}

variable "readonly_account_ids" {
  description = "Accounts the ReadOnly group can access"
  type        = list(string)
}
