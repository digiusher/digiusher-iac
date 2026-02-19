###############################################################################
# API Enablement
#
# Using disable_on_destroy = false to avoid breaking customer workloads.
###############################################################################

locals {
  required_apis = {
    # Always required
    "bigquery.googleapis.com"             = true
    "cloudbilling.googleapis.com"         = true
    "cloudresourcemanager.googleapis.com" = true
    "iam.googleapis.com"                  = true
    # Resource inventory
    "cloudasset.googleapis.com" = var.enable_resource_inventory
    # Optimization recommendations + CUD/reservation visibility
    "recommender.googleapis.com" = var.enable_recommendations
    "compute.googleapis.com"     = var.enable_recommendations
    "sqladmin.googleapis.com"    = var.enable_recommendations
    # Utilization metrics
    "monitoring.googleapis.com" = var.enable_monitoring
  }

  enabled_apis = { for api, enabled in local.required_apis : api => api if enabled }
}

resource "google_project_service" "digiusher" {
  for_each = local.enabled_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
