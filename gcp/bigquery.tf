###############################################################################
# BigQuery Dataset + Access
#
# Creates a BigQuery dataset for billing export (if requested) and grants
# the service account read access to the dataset.
#
# IMPORTANT: After running Terraform, you must manually enable billing
# export in the GCP Console. See GCP_BILLING_EXPORT_GUIDE.md.
###############################################################################

# Create the dataset (only if customer doesn't already have one)
resource "google_bigquery_dataset" "billing_export" {
  count = var.create_bigquery_dataset ? 1 : 0

  project    = var.project_id
  dataset_id = var.billing_export_dataset_id
  location   = var.bigquery_location

  friendly_name = "DigiUsher Billing Export"
  description   = "BigQuery dataset for GCP billing export data. Managed by DigiUsher onboarding Terraform."

  labels = {
    managed_by = "digiusher"
  }

  depends_on = [google_project_service.bigquery]
}

# Grant read access to the billing export dataset
# Works for both Terraform-created and pre-existing datasets
resource "google_bigquery_dataset_iam_member" "data_viewer" {
  project    = var.project_id
  dataset_id = var.billing_export_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = local.sa_member

  depends_on = [google_bigquery_dataset.billing_export]
}
