###############################################################################
# Project-Level IAM
#
# These roles are granted on the billing export project specifically.
###############################################################################

# Required to run BigQuery queries against billing export data
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = local.sa_member
}

# Required for Cloud Asset API calls
resource "google_project_iam_member" "service_usage_consumer" {
  count   = var.enable_resource_inventory ? 1 : 0
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = local.sa_member
}
