data "github_app" "actions" {
  slug = "github-actions"
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

resource "github_repository" "managed" {
  for_each = local.repositories

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility

  has_issues   = true
  has_projects = each.value.has_projects
  has_wiki     = each.value.has_wiki

  allow_auto_merge            = true
  delete_branch_on_merge      = true
  allow_squash_merge          = true
  allow_merge_commit          = false
  allow_rebase_merge          = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  topics = each.value.topics

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }

    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  lifecycle {
    prevent_destroy = true
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

resource "github_actions_variable" "dispatch_client_id" {
  for_each = local.versioned_repositories

  repository    = github_repository.managed[each.key].name
  variable_name = "TERNFORGE_DISPATCH_CLIENT_ID"
  value         = var.dispatch_client_id
}

resource "github_actions_variable" "renovate_client_id" {
  repository    = github_repository.managed["betabitplus/ternforge-infra-updates"].name
  variable_name = "TERNFORGE_RENOVATE_CLIENT_ID"
  value         = var.renovate_client_id
}

resource "github_app_installation_repositories" "release" {
  installation_id = var.release_app_installation_id
  selected_repositories = sort([
    for repository in keys(local.versioned_repositories) : github_repository.managed[repository].name
  ])
}

resource "github_app_installation_repositories" "dispatch" {
  installation_id       = var.dispatch_app_installation_id
  selected_repositories = [github_repository.managed["betabitplus/ternforge-infra-updates"].name]
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

resource "github_repository_ruleset" "release_tags" {
  for_each = local.versioned_repositories

  name        = "release-tags"
  repository  = github_repository.managed[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = each.value.release_tag_refs
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
