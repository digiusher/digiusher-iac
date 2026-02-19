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
  # Scope: org-wide vs limited to specific projects
  scope_org_wide = length(var.target_project_ids) == 0

  # All project IDs that need project-level roles (always includes the billing export project)
  target_projects = local.scope_org_wide ? [] : var.target_project_ids

  sa_email  = google_service_account.digiusher.email
  sa_member = "serviceAccount:${local.sa_email}"
}
