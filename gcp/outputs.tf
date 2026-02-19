###############################################################################
# Outputs
#
# These values are needed to configure your DigiUsher account.
# Run: terraform output -json > digiusher_credentials.json
###############################################################################

output "service_account_email" {
  value       = google_service_account.digiusher.email
  description = "Email of the DigiUsher service account."
}

output "service_account_key" {
  value       = google_service_account_key.digiusher.private_key
  sensitive   = true
  description = "Base64-encoded JSON key for the service account. Decode with: terraform output -raw service_account_key | base64 -d > digiusher-key.json"
}

output "project_id" {
  value       = var.project_id
  description = "GCP project hosting the billing export dataset."
}

output "organization_id" {
  value       = var.organization_id
  description = "GCP Organization ID."
}

output "billing_account_id" {
  value       = var.billing_account_id
  description = "GCP Billing Account ID."
}

output "bigquery_dataset_id" {
  value       = var.billing_export_dataset_id
  description = "BigQuery dataset ID containing billing export data."
}

output "bigquery_location" {
  value       = var.bigquery_location
  description = "BigQuery dataset location."
}

output "scope" {
  value       = local.scope_org_wide ? "organization-wide" : "limited to ${length(var.target_project_ids)} projects"
  description = "Access scope granted to DigiUsher."
}

output "next_step" {
  value       = var.create_bigquery_dataset ? "IMPORTANT: You must now enable billing export in the GCP Console. See GCP_BILLING_EXPORT_GUIDE.md. The dataset '${var.billing_export_dataset_id}' is ready." : "Verify billing export is active and data is flowing to '${var.billing_export_dataset_id}'."
  description = "Next step after Terraform apply."
}
