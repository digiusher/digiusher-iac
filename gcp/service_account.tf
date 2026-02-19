###############################################################################
# Service Account
#
# Creates a dedicated service account for DigiUsher with a JSON key.
# The key is output as a sensitive value for the customer to provide
# to the DigiUsher platform.
###############################################################################

resource "google_service_account" "digiusher" {
  project      = var.project_id
  account_id   = "digiusher-finops"
  display_name = "DigiUsher FinOps Platform"
  description  = "Read-only service account for DigiUsher cloud cost management. See https://github.com/digiusher/digiusher-iac"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_key" "digiusher" {
  service_account_id = google_service_account.digiusher.name
}
