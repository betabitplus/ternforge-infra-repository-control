removed {
  from = github_app_installation_repository.release

  lifecycle {
    destroy = false
  }
}

import {
  to = github_app_installation_repositories.release
  id = tostring(var.release_app_installation_id)
}
