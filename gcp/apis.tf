###############################################################################
# API Enablement
#
# These APIs must be enabled in the project before Terraform can create
# resources or grant IAM roles that depend on them.
# Using disable_on_destroy = false to avoid breaking customer workloads.
###############################################################################

# Always required
resource "google_project_service" "bigquery" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbilling" {
  project            = var.project_id
  service            = "cloudbilling.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudresourcemanager" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Resource inventory
resource "google_project_service" "cloudasset" {
  count              = var.enable_resource_inventory ? 1 : 0
  project            = var.project_id
  service            = "cloudasset.googleapis.com"
  disable_on_destroy = false
}

# Optimization recommendations
resource "google_project_service" "recommender" {
  count              = var.enable_recommendations ? 1 : 0
  project            = var.project_id
  service            = "recommender.googleapis.com"
  disable_on_destroy = false
}

# CUD/reservation visibility
resource "google_project_service" "compute" {
  count              = var.enable_recommendations ? 1 : 0
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Cloud SQL CUD/commitment visibility
resource "google_project_service" "sqladmin" {
  count              = var.enable_recommendations ? 1 : 0
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Utilization metrics
resource "google_project_service" "monitoring" {
  count              = var.enable_monitoring ? 1 : 0
  project            = var.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}
