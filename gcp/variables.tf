###############################################################################
# Required Variables
###############################################################################

variable "project_id" {
  type        = string
  description = "GCP project ID where the service account and BigQuery dataset will be created."
}

variable "organization_id" {
  type        = string
  description = "GCP Organization ID. Find with: gcloud organizations list"

  validation {
    condition     = can(regex("^[0-9]+$", var.organization_id))
    error_message = "Organization ID must be a numeric string (e.g. \"123456789012\"). Find yours with: gcloud organizations list"
  }
}

variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID. Find with: gcloud billing accounts list"

  validation {
    condition     = can(regex("^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}$", var.billing_account_id))
    error_message = "Billing Account ID must be in format XXXXXX-XXXXXX-XXXXXX (e.g. \"01D6D8-E2C91C-117E5D\"). Find yours with: gcloud billing accounts list"
  }
}

###############################################################################
# Scope
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
  description = "BigQuery dataset location. When creating a new dataset, must be US or EU (multi-region) for billing export backfill."
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
