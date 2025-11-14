# Configure the Azure AD provider
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.36.0"
    }
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ============================================================================
# VARIABLES
# ============================================================================

variable "subscription_id" {
  type        = string
  description = "The Subscription ID which should be used to create the application"
}

variable "tenant_id" {
  type        = string
  description = "The Tenant ID which should be used"
}

variable "target_subscription_ids" {
  type        = list(string)
  description = "List of specific subscription IDs to target. If empty, all subscriptions will be used."
  default     = []
}

variable "enable_power_scheduler" {
  type        = bool
  description = "If true, adds permissions to start and deallocate (stop) VMs"
  default     = false
}

variable "enable_cost_exports" {
  type        = bool
  description = "Creates FOCUS cost exports and assigns necessary permissions"
  default     = true
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID. For EA: enrollment number. For MCA: billing account ID. Leave empty to use subscription scope (not recommended for production)."
  default     = ""
}

variable "billing_profile_id" {
  type        = string
  description = "Billing profile ID (only required for MCA). Leave empty for EA."
  default     = ""
}

variable "storage_account_name" {
  type        = string
  description = "Name of the storage account for cost exports (must be globally unique). Leave empty for auto-generated name."
  default     = ""
}

variable "storage_container_name" {
  type        = string
  description = "Container name for cost exports"
  default     = "digiusher-focus-exports"
}

variable "export_recurrence" {
  type        = string
  description = "Export schedule: Daily, Weekly, Monthly, or Annually"
  default     = "Daily"
}

variable "focus_version" {
  type        = string
  description = "FOCUS dataset version"
  default     = "1.0"
}

variable "export_file_format" {
  type        = string
  description = "Export file format: Csv or Parquet"
  default     = "Csv"
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
data "azurerm_subscriptions" "available" {}

# ============================================================================
# LOCALS
# ============================================================================

locals {
  # Subscription targeting
  all_subscriptions = [
    for s in data.azurerm_subscriptions.available.subscriptions : s.subscription_id
  ]
  subscriptions = length(var.target_subscription_ids) > 0 ? var.target_subscription_ids : local.all_subscriptions

  # Storage account naming
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : "digiusher${substr(md5(var.tenant_id), 0, 10)}"

  # Billing scope determination
  billing_scope = var.billing_account_id != "" ? (
    var.billing_profile_id != "" ?
      "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingProfiles/${var.billing_profile_id}" :
      "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}"
  ) : "/subscriptions/${var.subscription_id}"

  billing_scope_type = var.billing_account_id != "" ? (
    var.billing_profile_id != "" ? "MCA" : "EA"
  ) : "Subscription"
}

# ============================================================================
# AZURE AD APPLICATION AND SERVICE PRINCIPAL
# ============================================================================

resource "azuread_application" "digiusher_app" {
  display_name = "DigiUsherApp"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "digiusher_app_sp" {
  client_id                    = azuread_application.digiusher_app.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "app_password" {
  display_name   = "DigiUsherApp Secret"
  application_id = azuread_application.digiusher_app.id
}

# ============================================================================
# SUBSCRIPTION-LEVEL ROLE ASSIGNMENTS
# ============================================================================

resource "azurerm_role_assignment" "app_role_assignment" {
  count                = length(local.subscriptions)
  scope                = "/subscriptions/${local.subscriptions[count.index]}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.digiusher_app_sp.object_id
}

# ============================================================================
# POWER SCHEDULER (OPTIONAL)
# ============================================================================

resource "azurerm_role_definition" "digiusher_power_scheduler" {
  count       = var.enable_power_scheduler ? 1 : 0
  name        = "DigiUsher Power Scheduler"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Custom role for managing VM start/deallocate actions"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/read"
    ]
    not_actions = []
  }

  assignable_scopes = [for sub_id in local.subscriptions : "/subscriptions/${sub_id}"]
}

resource "azurerm_role_assignment" "digiusher_power_scheduler_role_assignment" {
  count              = var.enable_power_scheduler ? length(local.subscriptions) : 0
  scope              = "/subscriptions/${local.subscriptions[count.index]}"
  role_definition_id = azurerm_role_definition.digiusher_power_scheduler[0].role_definition_resource_id
  principal_id       = azuread_service_principal.digiusher_app_sp.object_id
}

# ============================================================================
# RESERVATIONS AND SAVINGS PLANS
# ============================================================================

data "azurerm_role_definition" "reservations_reader" {
  name = "Reservations Reader"
}

data "azurerm_role_definition" "savings_plan_reader" {
  name = "Savings Plan Reader"
}

resource "azapi_resource" "digiusher_reservations_reader" {
  name      = uuid()
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/providers/Microsoft.Capacity"
  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = data.azurerm_role_definition.reservations_reader.id
      principalType    = "ServicePrincipal"
    }
  }
}

resource "azapi_resource" "digiusher_savings_plan_reader" {
  name      = uuid()
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/providers/Microsoft.BillingBenefits"
  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = data.azurerm_role_definition.savings_plan_reader.id
      principalType    = "ServicePrincipal"
    }
  }
}

# ============================================================================
# FOCUS EXPORT RESOURCES
# ============================================================================

resource "azurerm_resource_group" "export_rg" {
  count    = var.enable_cost_exports ? 1 : 0
  name     = "digiusher-billing-exports"
  location = "eastus"
}

resource "azurerm_storage_account" "export_storage" {
  count                    = var.enable_cost_exports ? 1 : 0
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.export_rg[0].name
  location                 = azurerm_resource_group.export_rg[0].location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = {
    purpose = "DigiUsher Cost Exports"
  }
}

resource "azurerm_storage_container" "export_container" {
  count                 = var.enable_cost_exports ? 1 : 0
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.export_storage[0].name
  container_access_type = "private"
}

# Cost Management Reader at billing scope
resource "azapi_resource" "cost_management_reader_assignment" {
  count     = var.enable_cost_exports ? 1 : 0
  name      = uuid()
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = local.billing_scope

  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = "${local.billing_scope}/providers/Microsoft.Authorization/roleDefinitions/72fafb9e-0641-4937-9268-a91bfd8191a3"
      principalType    = "ServicePrincipal"
    }
  }
}

# Storage Blob Data Contributor for the export
resource "azurerm_role_assignment" "storage_blob_contributor" {
  count                = var.enable_cost_exports ? 1 : 0
  scope                = azurerm_storage_account.export_storage[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.digiusher_app_sp.object_id
}

# Create FOCUS export
resource "azapi_resource" "focus_export" {
  count     = var.enable_cost_exports ? 1 : 0
  name      = "digiusher-focus-export"
  type      = "Microsoft.CostManagement/exports@2023-07-01-preview"
  parent_id = local.billing_scope

  body = {
    identity = {
      type = "SystemAssigned"
    }
    location = "centralus"
    properties = {
      schedule = {
        status     = "Active"
        recurrence = var.export_recurrence
        recurrencePeriod = {
          from = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timestamp())
          to   = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timeadd(timestamp(), "26280h"))
        }
      }
      format = var.export_file_format
      deliveryInfo = {
        destination = {
          type           = "AzureBlob"
          resourceId     = azurerm_storage_account.export_storage[0].id
          container      = var.storage_container_name
          rootFolderPath = "focus"
        }
      }
      definition = {
        type      = "FocusCost"
        timeframe = "MonthToDate"
        dataSet = {
          granularity = "Daily"
          configuration = {
            dataVersion = var.focus_version
          }
        }
      }
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      compressionMode       = "gzip"
      exportDescription     = "DigiUsher FOCUS cost export"
    }
  }

  depends_on = [
    azurerm_storage_container.export_container,
    azurerm_role_assignment.storage_blob_contributor,
    azapi_resource.cost_management_reader_assignment
  ]

  lifecycle {
    ignore_changes = [
      body.properties.schedule.recurrencePeriod
    ]
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "application_id" {
  description = "The Application ID (Client ID) of the DigiUsher application"
  value       = azuread_application.digiusher_app.client_id
}

output "tenant_id" {
  description = "The Tenant ID where the application is registered"
  value       = var.tenant_id
}

output "client_secret" {
  description = "The Client Secret for the DigiUsher application"
  value       = azuread_application_password.app_password.value
  sensitive   = true
}

output "storage_account_name" {
  description = "Storage account name for cost exports"
  value       = var.enable_cost_exports ? azurerm_storage_account.export_storage[0].name : null
}

output "storage_container_name" {
  description = "Container name for cost exports"
  value       = var.enable_cost_exports ? var.storage_container_name : null
}

output "export_name" {
  description = "Name of the FOCUS export"
  value       = var.enable_cost_exports ? azapi_resource.focus_export[0].name : null
}

output "billing_scope" {
  description = "Billing scope used for the export"
  value       = var.enable_cost_exports ? local.billing_scope : null
}

output "billing_scope_type" {
  description = "Detected billing scope type (EA, MCA, or Subscription)"
  value       = var.enable_cost_exports ? local.billing_scope_type : null
}

output "backfill_command" {
  description = "Command to run historical data backfill"
  value = var.enable_cost_exports ? "python3 backfill_historical_data.py --tenant-id ${var.tenant_id} --client-id ${azuread_application.digiusher_app.client_id} --billing-scope '${local.billing_scope}' --export-name ${azapi_resource.focus_export[0].name} --months 13" : null
}
