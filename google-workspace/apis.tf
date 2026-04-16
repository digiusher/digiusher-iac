###############################################################################
# API Enablement
#
# Using disable_on_destroy = false to avoid breaking customer workloads.
###############################################################################

locals {
  required_apis = {
    "admin.googleapis.com"     = true # Admin SDK (Directory + Reports APIs)
    "licensing.googleapis.com" = true # Enterprise License Manager API
    "iam.googleapis.com"       = true # Required for service account creation
  }

  enabled_apis = { for api, enabled in local.required_apis : api => api if enabled }
}

resource "google_project_service" "digiusher_workspace" {
  for_each = local.enabled_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
