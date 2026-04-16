###############################################################################
# Required Variables
###############################################################################

variable "project_id" {
  type        = string
  description = <<-EOT
    GCP project ID where the service account will be created.
    This can be any project in your organization.
    Find yours with: gcloud projects list
  EOT

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 lowercase letters, digits, or hyphens, starting with a letter. Find yours with: gcloud projects list"
  }
}
