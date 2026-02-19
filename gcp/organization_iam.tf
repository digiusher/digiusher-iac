###############################################################################
# Resource Access Roles (Org-Wide or Per-Project)
#
# Scope logic (mirrors Azure's target_subscription_ids pattern):
#   - target_project_ids empty  → org-wide access (recommended)
#   - target_project_ids set    → per-project access (POC/limited)
#
# Org-wide grants automatically cover new projects created in the future.
###############################################################################

locals {
  # Roles that are always granted (core visibility)
  core_roles = toset(["roles/browser"])

  # Roles gated by feature flags
  inventory_roles      = var.enable_resource_inventory ? toset(["roles/cloudasset.viewer"]) : toset([])
  recommendation_roles = var.enable_recommendations ? toset(["roles/recommender.viewer", "roles/compute.viewer", "roles/cloudsql.viewer"]) : toset([])
  monitoring_roles     = var.enable_monitoring ? toset(["roles/monitoring.viewer"]) : toset([])
  tag_roles            = toset(["roles/resourcemanager.tagViewer"])

  # Combined set of all roles to grant
  all_resource_roles = setunion(
    local.core_roles,
    local.inventory_roles,
    local.recommendation_roles,
    local.monitoring_roles,
    local.tag_roles,
  )
}

# -----------------------------------------------------------------------------
# Org-wide access (recommended - covers all current and future projects)
# -----------------------------------------------------------------------------

resource "google_organization_iam_member" "digiusher" {
  for_each = local.scope_org_wide ? local.all_resource_roles : toset([])

  org_id = var.organization_id
  role   = each.value
  member = local.sa_member
}

# -----------------------------------------------------------------------------
# Per-project access (POC/limited scope)
# -----------------------------------------------------------------------------

locals {
  # Create a flat set of (project_id, role) pairs for per-project bindings
  project_role_pairs = {
    for pair in setproduct(toset(local.target_projects), local.all_resource_roles) :
    "${pair[0]}:${pair[1]}" => {
      project_id = pair[0]
      role       = pair[1]
    }
  }
}

resource "google_project_iam_member" "digiusher_scoped" {
  for_each = local.scope_org_wide ? {} : local.project_role_pairs

  project = each.value.project_id
  role    = each.value.role
  member  = local.sa_member
}
