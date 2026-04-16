###############################################################################
# Service Account
#
# Creates a dedicated service account for DigiUsher Google Workspace
# integration with a JSON key. The key is output as a sensitive value
# for the customer to provide to the DigiUsher platform.
#
# After Terraform, the customer must:
#   1. Configure Domain-Wide Delegation in the Google Admin Console
#   2. Create a custom admin role with read-only Workspace permissions
#   3. Assign the role to a delegated admin user
###############################################################################

resource "google_service_account" "digiusher_workspace" {
  project      = var.project_id
  account_id   = "digiusher-workspace"
  display_name = "DigiUsher Workspace Integration"
  description  = "Service account for DigiUsher Google Workspace license cost tracking. Requires Domain-Wide Delegation. See https://github.com/digiusher/digiusher-iac"

  depends_on = [google_project_service.digiusher_workspace]
}

resource "google_service_account_key" "digiusher_workspace" {
  service_account_id = google_service_account.digiusher_workspace.name
}
