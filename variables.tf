variable "grafana_app_id" {
  description = "Public App ID for the permanent ternforge-fleet-health GitHub App."
  type        = number
}

variable "grafana_app_installation_id" {
  description = "Selected-repository installation ID for the permanent ternforge-fleet-health GitHub App."
  type        = number
}

variable "grafana_otlp_endpoint" {
  description = "Public Grafana Cloud OTLP endpoint used by Fleet Health telemetry."
  type        = string
}

variable "grafana_otlp_username" {
  description = "Public Grafana Cloud OTLP username used by Fleet Health telemetry."
  type        = string
}

variable "grafana_stack_slug" {
  description = "Grafana Cloud stack slug used by Fleet Health management."
  type        = string
}

variable "release_app_id" {
  description = "Public App ID for the permanent ternforge-release GitHub App."
  type        = number
}

variable "release_app_installation_id" {
  description = "Selected-repository installation ID for the permanent ternforge-release GitHub App."
  type        = number
}

variable "release_client_id" {
  description = "Public client ID of the permanent ternforge-release GitHub App."
  type        = string
}

variable "renovate_app_installation_id" {
  description = "Selected-repository installation ID for the permanent ternforge-renovate GitHub App."
  type        = number
}

variable "renovate_client_id" {
  description = "Public client ID of the permanent ternforge-renovate GitHub App."
  type        = string
}

variable "source_read_app_installation_id" {
  description = "Selected-repository installation ID for the permanent ternforge-source-read GitHub App."
  type        = number
}

variable "source_read_client_id" {
  description = "Public client ID of the permanent ternforge-source-read GitHub App."
  type        = string
}

variable "repositories" {
  description = "Single authoritative Ternforge fleet inventory and repository-control configuration."

  type = list(object({
    repository             = string
    description            = string
    visibility             = string
    has_projects           = bool
    has_wiki               = bool
    versioned              = bool
    topics                 = list(string)
    docs_mode              = optional(string, "")
    docs_runner            = optional(string, "")
    docs_local_environment = optional(bool, false)
  }))

  validation {
    condition     = length(var.repositories) > 0 && length(var.repositories) < 500
    error_message = "Managed fleet must contain between 1 and 499 repositories."
  }

  validation {
    condition     = length(var.repositories) == length(distinct([for repository in var.repositories : repository.repository]))
    error_message = "Each managed repository must appear exactly once."
  }

  validation {
    condition     = tolist([for repository in var.repositories : repository.repository]) == sort([for repository in var.repositories : repository.repository])
    error_message = "Managed repository full names must be deterministically sorted."
  }

  validation {
    condition = alltrue([
      for repository in var.repositories :
      can(regex("^betabitplus/[a-z0-9][a-z0-9-]*$", repository.repository))
    ])
    error_message = "Managed repositories must be normalized betabitplus repositories."
  }

  validation {
    condition = alltrue([
      for repository in var.repositories :
      contains(["public", "private"], repository.visibility)
    ])
    error_message = "Repository visibility must be public or private."
  }

  validation {
    condition = alltrue([
      for repository in var.repositories :
      contains(["", "manual", "release"], repository.docs_mode)
    ])
    error_message = "docs_mode must be empty, manual, or release."
  }

  validation {
    condition = alltrue([
      for repository in var.repositories :
      repository.docs_mode == "" || repository.docs_runner != ""
    ])
    error_message = "Docs-enabled repositories must declare docs_runner."
  }

  validation {
    condition = alltrue([
      for repository in var.repositories :
      !repository.docs_local_environment || repository.docs_mode == "manual"
    ])
    error_message = "docs_local_environment is only valid for manual docs mode."
  }
}
