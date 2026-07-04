variable "name_prefix" {
  type = string
}

variable "allowed_regions" {
  type = list(string)
}

variable "service_access_principals" {
  type = list(string)
}

variable "log_archive_email" {
  description = "Unique email for the log-archive member account"
  type        = string
}

variable "org_access_role_name" {
  type = string
}
