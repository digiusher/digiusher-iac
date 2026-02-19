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
  region  = var.region
}

locals {
  scope_org_wide  = length(var.target_project_ids) == 0
  target_projects = var.target_project_ids

  sa_email  = google_service_account.digiusher.email
  sa_member = "serviceAccount:${local.sa_email}"
}
