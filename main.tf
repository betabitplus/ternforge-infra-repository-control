data "github_app" "actions" {
  slug = "github-actions"
}

data "github_user" "owner" {
  username = "betabitplus"
}

locals {
  repositories = {
    for repository in var.repositories : repository.repository => merge(repository, {
      name = split("/", repository.repository)[1]
    })
  }

  versioned_repositories = {
    for repository, settings in local.repositories : repository => settings
    if settings.versioned
  }
}

import {
  for_each = local.repositories

  to = github_repository.managed[each.key]
  id = each.value.name
}

import {
  for_each = local.versioned_repositories

  to = github_actions_variable.release_client_id[each.key]
  id = "${each.value.name}:TERNFORGE_RELEASE_CLIENT_ID"
}

import {
  for_each = local.versioned_repositories

  to = github_repository_environment.release[each.key]
  id = "${each.value.name}:release"
}

resource "github_repository" "managed" {
  for_each = local.repositories

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility

  has_issues   = true
  has_projects = each.value.has_projects
  has_wiki     = each.value.has_wiki

  allow_auto_merge            = false
  delete_branch_on_merge      = true
  allow_squash_merge          = true
  allow_merge_commit          = false
  allow_rebase_merge          = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  topics = each.value.topics

  dynamic "security_and_analysis" {
    for_each = each.value.visibility == "public" ? [true] : []

    content {
      secret_scanning {
        status = "enabled"
      }

      secret_scanning_push_protection {
        status = "enabled"
      }
    }
  }

  lifecycle {
    destroy = false
  }
}

resource "github_branch_default" "main" {
  for_each = local.repositories

  repository = github_repository.managed[each.key].name
  branch     = "main"
}

resource "github_workflow_repository_permissions" "managed" {
  for_each = local.repositories

  repository                       = github_repository.managed[each.key].name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false
}

resource "github_repository_environment" "release" {
  for_each = local.versioned_repositories

  repository        = github_repository.managed[each.key].name
  environment       = "release"
  can_admins_bypass = false

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "repository_control_apply" {
  repository          = github_repository.managed["betabitplus/ternforge-infra-repository-control"].name
  environment         = "repository-control-apply"
  can_admins_bypass   = false
  prevent_self_review = false

  reviewers {
    users = [data.github_user.owner.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "renovate" {
  repository        = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  environment       = "renovate"
  can_admins_bypass = false

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "grafana" {
  repository          = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  environment         = "grafana"
  can_admins_bypass   = false
  prevent_self_review = false

  reviewers {
    users = [data.github_user.owner.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "release" {
  for_each = local.versioned_repositories

  repository     = github_repository.managed[each.key].name
  environment    = github_repository_environment.release[each.key].environment
  branch_pattern = "main"
}

resource "github_repository_environment_deployment_policy" "repository_control_apply" {
  repository     = github_repository.managed["betabitplus/ternforge-infra-repository-control"].name
  environment    = github_repository_environment.repository_control_apply.environment
  branch_pattern = "main"
}

resource "github_repository_environment_deployment_policy" "renovate" {
  repository     = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  environment    = github_repository_environment.renovate.environment
  branch_pattern = "main"
}

resource "github_repository_environment_deployment_policy" "grafana" {
  repository     = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  environment    = github_repository_environment.grafana.environment
  branch_pattern = "main"
}

resource "github_repository_vulnerability_alerts" "managed" {
  for_each = local.repositories

  repository = github_repository.managed[each.key].name
  enabled    = true
}

resource "github_actions_variable" "release_client_id" {
  for_each = local.versioned_repositories

  repository    = github_repository.managed[each.key].name
  variable_name = "TERNFORGE_RELEASE_CLIENT_ID"
  value         = var.release_client_id
}

resource "github_actions_variable" "renovate_client_id" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_RENOVATE_CLIENT_ID"
  value         = var.renovate_client_id
}

resource "github_actions_variable" "grafana_installation_id" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_GRAFANA_GITHUB_INSTALLATION_ID"
  value         = tostring(var.grafana_app_installation_id)
}

resource "github_actions_variable" "grafana_app_id" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_GRAFANA_GITHUB_APP_ID"
  value         = tostring(var.grafana_app_id)
}

resource "github_actions_variable" "grafana_stack_slug" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_GRAFANA_STACK_SLUG"
  value         = var.grafana_stack_slug
}

resource "github_actions_variable" "grafana_otlp_endpoint" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_GRAFANA_OTLP_ENDPOINT"
  value         = var.grafana_otlp_endpoint
}

resource "github_actions_variable" "grafana_otlp_username" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_GRAFANA_OTLP_USERNAME"
  value         = var.grafana_otlp_username
}

resource "github_app_installation_repositories" "grafana" {
  installation_id = var.grafana_app_installation_id
  selected_repositories = sort([
    for repository in keys(local.repositories) : github_repository.managed[repository].name
  ])
}

resource "github_app_installation_repositories" "release" {
  installation_id = var.release_app_installation_id
  selected_repositories = sort([
    for repository in keys(local.versioned_repositories) : github_repository.managed[repository].name
  ])
}

resource "github_app_installation_repositories" "renovate" {
  installation_id = var.renovate_app_installation_id
  selected_repositories = sort([
    for repository in keys(local.repositories) : github_repository.managed[repository].name
  ])
}

resource "github_repository_ruleset" "main" {
  for_each = local.repositories

  name        = "main"
  repository  = github_repository.managed[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      allowed_merge_methods             = ["squash"]
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 0
      required_review_thread_resolution = false
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context        = "ci / required"
        integration_id = tonumber(data.github_app.actions.id)
      }
    }
  }

  depends_on = [github_branch_default.main]
}

resource "github_repository_ruleset" "main_updates" {
  for_each = local.repositories

  name        = "main-updates"
  repository  = github_repository.managed[each.key].name
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "pull_request"
  }

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    update = true
  }

  depends_on = [github_branch_default.main]
}

resource "github_repository_ruleset" "release_tags" {
  for_each = local.versioned_repositories

  name        = "release-tags"
  repository  = github_repository.managed[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true
    update           = true
  }

  depends_on = [github_branch_default.main]
}
