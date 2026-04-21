terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

locals {
  sa_email  = google_service_account.digiusher_workspace.email
  sa_member = "serviceAccount:${local.sa_email}"

  # OAuth scopes for Domain-Wide Delegation.
  # All scopes are included upfront so customers don't need to revisit
  # the Admin Console when new DigiUsher features are enabled.
  dwd_scopes = [
    "https://www.googleapis.com/auth/admin.directory.user.readonly",
    "https://www.googleapis.com/auth/admin.reports.usage.readonly",
    "https://www.googleapis.com/auth/admin.reports.audit.readonly",
    "https://www.googleapis.com/auth/apps.licensing",
  ]
}
