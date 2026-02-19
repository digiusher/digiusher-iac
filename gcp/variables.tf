###############################################################################
# Required Variables
###############################################################################

variable "project_id" {
  type        = string
  description = "GCP project ID where the service account and BigQuery dataset will be created."
}

variable "organization_id" {
  type        = string
  description = <<-EOT
    GCP Organization ID. Required for org-wide resource visibility.
    Find yours with: gcloud organizations list
    Or in the Console: IAM & Admin > Settings
  EOT
}

variable "billing_account_id" {
  type        = string
  description = <<-EOT
    GCP Billing Account ID.
    Find yours with: gcloud billing accounts list
    Or in the Console: Billing > Manage billing accounts
  EOT
}

###############################################################################
# Scope Limiting (like Azure's target_subscription_ids)
###############################################################################

variable "target_project_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Specific project IDs to limit access to. If empty (default), grants
    org-wide access covering all current and future projects (recommended).
    Set this for POC/limited onboarding, e.g. ["my-project-1", "my-project-2"].
  EOT
}

###############################################################################
# BigQuery Configuration
###############################################################################

variable "create_bigquery_dataset" {
  type        = bool
  default     = true
  description = "Create a new BigQuery dataset for billing export. Set to false if you already have one."
}

variable "billing_export_dataset_id" {
  type        = string
  default     = "digiusher_billing_export"
  description = "BigQuery dataset ID for billing export data. Used for both new and existing datasets."
}

variable "bigquery_location" {
  type        = string
  default     = "US"
  description = <<-EOT
    BigQuery dataset location. Must be a multi-region (US or EU) to get
    previous month's billing data backfilled automatically. Regional datasets
    only receive data from the day the export is enabled.
  EOT

  validation {
    condition     = contains(["US", "EU"], var.bigquery_location)
    error_message = "BigQuery location must be US or EU (multi-region) for billing export backfill."
  }
}

###############################################################################
# Feature Flags
###############################################################################

variable "enable_resource_inventory" {
  type        = bool
  default     = true
  description = "Grant Cloud Asset API access for resource inventory across the organization."
}

variable "enable_recommendations" {
  type        = bool
  default     = true
  description = "Grant Recommender API access for cost optimization recommendations (rightsizing, idle resources, CUDs)."
}

variable "enable_monitoring" {
  type        = bool
  default     = true
  description = "Grant Cloud Monitoring access for utilization metrics (CPU, memory, network, disk)."
}

###############################################################################
# Internal / Advanced
###############################################################################

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Default GCP region for the provider."
}
