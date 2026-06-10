terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.71"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "workspace_host" {
  description = "Workspace hostname without https://, e.g. abc-123.cloud.databricks.com"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (top-right corner of accounts.cloud.databricks.com)"
  type        = string
}

variable "warehouse_id" {
  description = "SQL warehouse ID from Connection details HTTP path"
  type        = string
}

variable "databricks_token" {
  description = "Admin PAT used by Terraform to bootstrap (not needed after apply)"
  type        = string
  sensitive   = true
}

variable "service_principal_name" {
  description = "Display name for the billing reader service principal"
  type        = string
  default     = "digisuher-focus-reader"
}

# ── Provider ──────────────────────────────────────────────────────────────────

provider "databricks" {
  host  = "https://${var.workspace_host}"
  token = var.databricks_token
}

# ── Service Principal ─────────────────────────────────────────────────────────

resource "databricks_service_principal" "digiusher_focus_reader" {
  display_name = var.service_principal_name
}

resource "databricks_service_principal_secret" "digiusher_focus_reader" {
  service_principal_id = databricks_service_principal.digiusher_focus_reader.id
}

# ── Warehouse permission ──────────────────────────────────────────────────────

resource "databricks_permissions" "warehouse" {
  sql_endpoint_id = var.warehouse_id

  access_control {
    service_principal_name = databricks_service_principal.digiusher_focus_reader.application_id
    permission_level       = "CAN_USE"
  }
}

# ── Unity Catalog grants ──────────────────────────────────────────────────────

locals {
  sp_id = databricks_service_principal.digiusher_focus_reader.application_id
}

resource "databricks_grant" "system_catalog" {
  catalog    = "system"
  principal  = local.sp_id
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "billing_schema" {
  schema     = "system.billing"
  principal  = local.sp_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "billing_usage" {
  table      = "system.billing.usage"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "billing_list_prices" {
  table      = "system.billing.list_prices"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "access_schema" {
  schema     = "system.access"
  principal  = local.sp_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "access_workspaces_latest" {
  table      = "system.access.workspaces_latest"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "compute_schema" {
  schema     = "system.compute"
  principal  = local.sp_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "compute_clusters" {
  table      = "system.compute.clusters"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "compute_warehouses" {
  table      = "system.compute.warehouses"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "lakeflow_schema" {
  schema     = "system.lakeflow"
  principal  = local.sp_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "lakeflow_pipelines" {
  table      = "system.lakeflow.pipelines"
  principal  = local.sp_id
  privileges = ["SELECT"]
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "client_id" {
  description = "DATABRICKS_CLIENT_ID"
  value       = databricks_service_principal.digiusher_focus_reader.application_id
}

output "client_secret" {
  description = "DATABRICKS_CLIENT_SECRET"
  value       = databricks_service_principal_secret.digiusher_focus_reader.secret
  sensitive   = true
}

output "workspace_hostname" {
  description = "DATABRICKS_HOST"
  value       = var.workspace_host
}

output "http_path" {
  description = "DATABRICKS_HTTP_PATH"
  value       = "/sql/1.0/warehouses/${var.warehouse_id}"
}
