###############################################################################
# Organization / Project IAM
#
# Scope logic:
#   - target_project_ids empty  -> org-wide access (recommended)
#   - target_project_ids set    -> per-project access (POC/limited)
#
# Org-wide grants automatically cover new projects created in the future.
###############################################################################

locals {
  # Build the set of roles to grant based on feature flags
  all_resource_roles = setunion(
    toset([
      "roles/browser",
      "roles/resourcemanager.tagViewer",
    ]),
    var.enable_resource_inventory ? toset(["roles/cloudasset.viewer"]) : [],
    var.enable_recommendations ? toset(["roles/recommender.viewer", "roles/compute.viewer", "roles/cloudsql.viewer"]) : [],
    var.enable_monitoring ? toset(["roles/monitoring.viewer"]) : [],
  )

  # Flat map of (project, role) pairs for per-project bindings
  project_role_pairs = {
    for pair in setproduct(toset(local.target_projects), local.all_resource_roles) :
    "${pair[0]}:${pair[1]}" => {
      project_id = pair[0]
      role       = pair[1]
    }
  }
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

resource "google_project_iam_member" "digiusher_scoped" {
  for_each = local.scope_org_wide ? {} : local.project_role_pairs

  project = each.value.project_id
  role    = each.value.role
  member  = local.sa_member
}
