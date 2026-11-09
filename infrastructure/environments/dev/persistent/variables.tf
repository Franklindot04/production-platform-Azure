variable "env" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "log_retention_days" {
  type        = number
  description = "Retention of the Log Analytics workspace, in days."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "log_daily_cap_gb" {
  type        = number
  description = "Daily ingestion cap of the Log Analytics workspace, in GB."
  default     = 0.5

  validation {
    condition     = var.log_daily_cap_gb >= 0.023
    error_message = "The daily cap must be at least 0.023 GB."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address of the action group receiver. Set at run time with TF_VAR_alert_email. No default."
  sensitive   = true

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.alert_email))
    error_message = "alert_email must look like an email address."
  }
}

variable "github_repository" {
  type        = string
  description = "Repository allowed to get a token for pull request plans, as <owner>/<name>."
  default     = "Franklindot04/production-platform-Azure"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be <owner>/<name>."
  }
}

variable "github_owner_id" {
  type        = string
  description = "The numeric ID of the repository owner, as presented in the subject of the token. Set at run time with TF_VAR_github_owner_id. No default."

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the numeric GitHub ID of the repository owner."
  }
}

variable "github_repository_id" {
  type        = string
  description = "The numeric ID of the repository, as presented in the subject of the token. Set at run time with TF_VAR_github_repository_id. No default."

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be the numeric GitHub ID of the repository."
  }
}

variable "state_account_name" {
  type        = string
  description = "Name of the state storage account. Set at run time with TF_VAR_state_account_name. No default."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_account_name))
    error_message = "A storage account name has 3 to 24 lower case letters and digits."
  }
}

variable "state_resource_group_name" {
  type    = string
  default = "pp-shared-state-rg"
}
