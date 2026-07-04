variable "name_prefix" {
  type = string
}

variable "org_id" {
  type = string
}

variable "management_account_id" {
  type = string
}

variable "log_archive_account_id" {
  type = string
}

variable "retention_days" {
  description = "Object lock default retention. Kept short so demo teardown is clean."
  type        = number
  default     = 1
}
