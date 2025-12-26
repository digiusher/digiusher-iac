# Configure the Azure AD provider
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

variable "billing_scope_level" {
  type        = string
  description = "Billing scope level: billing_account (EA/MCA top-level), enrollment_account (EA sub-scope), invoice_section (MCA sub-scope), customer (MPA/CSP), or subscription"
  default     = "billing_account"

  validation {
    condition     = contains(["billing_account", "enrollment_account", "invoice_section", "customer", "subscription"], var.billing_scope_level)
    error_message = "billing_scope_level must be one of: billing_account, enrollment_account, invoice_section, customer, subscription"
  }
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID. For EA: enrollment number. For MCA: billing account ID. Leave empty to use subscription scope (not recommended for production)."
  default     = ""
}

variable "enrollment_account_id" {
  type        = string
  description = "Enrollment Account ID (only for EA with enrollment_account scope). Leave empty for billing_account level."
  default     = ""
}

variable "billing_profile_id" {
  type        = string
  description = "Billing profile ID (only required for MCA invoice_section scope). Leave empty for EA or billing_account level."
  default     = ""
}

variable "invoice_section_id" {
  type        = string
  description = "Invoice Section ID (only for MCA with invoice_section scope). Leave empty for other scopes."
  default     = ""
}

variable "customer_id" {
  type        = string
  description = "Customer ID (only for MPA/CSP with customer scope). Leave empty for other scopes."
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

variable "export_file_format" {
  type        = string
  description = "Export file format: Csv or Parquet"
  default     = "Csv"
}

variable "export_root_path" {
  type        = string
  description = "Root folder path within the container for exports"
  default     = "focus"
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

  # Detect billing account type: MCA billing account IDs contain colons
  is_mca = var.billing_account_id != "" && can(regex(":", var.billing_account_id))

  # Billing scope determination
  billing_scope = (
    var.billing_scope_level == "enrollment_account" ?
    "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/enrollmentAccounts/${var.enrollment_account_id}" :
    var.billing_scope_level == "invoice_section" ?
    "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingProfiles/${var.billing_profile_id}/invoiceSections/${var.invoice_section_id}" :
    var.billing_scope_level == "customer" ?
    "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/customers/${var.customer_id}" :
    var.billing_scope_level == "billing_account" ?
    "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}" :
    "/subscriptions/${var.subscription_id}"
  )

  billing_scope_type = (
    var.billing_scope_level == "enrollment_account" ? "EA-EnrollmentAccount" :
    var.billing_scope_level == "invoice_section" ? "MCA-InvoiceSection" :
    var.billing_scope_level == "customer" ? "MPA-Customer" :
    var.billing_scope_level == "billing_account" ? (local.is_mca ? "MCA-BillingAccount" : "EA-BillingAccount") :
    "Subscription"
  )
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
  name      = uuidv5("dns", "${azuread_service_principal.digiusher_app_sp.object_id}-reservations-reader")
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/providers/Microsoft.Capacity"
  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = data.azurerm_role_definition.reservations_reader.id
      principalType    = "ServicePrincipal"
    }
  }

  lifecycle {
    ignore_changes = [name]
  }
}

resource "azapi_resource" "digiusher_savings_plan_reader" {
  name      = uuidv5("dns", "${azuread_service_principal.digiusher_app_sp.object_id}-savings-plan-reader")
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/providers/Microsoft.BillingBenefits"
  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = data.azurerm_role_definition.savings_plan_reader.id
      principalType    = "ServicePrincipal"
    }
  }

  lifecycle {
    ignore_changes = [name]
  }
}

# ============================================================================
# FOCUS EXPORT RESOURCES
# ============================================================================

# Register the CostManagementExports provider (required for exports)
resource "azurerm_resource_provider_registration" "cost_management_exports" {
  count = var.enable_cost_exports ? 1 : 0
  name  = "Microsoft.CostManagementExports"
}

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

  tags = {
    purpose = "DigiUsher Cost Exports"
  }
}

resource "azurerm_storage_container" "export_container" {
  count                 = var.enable_cost_exports ? 1 : 0
  name                  = var.storage_container_name
  storage_account_id  = azurerm_storage_account.export_storage[0].id
  container_access_type = "private"
}

# Cost Management Contributor at billing scope (for EA - required to trigger exports)
resource "azapi_resource" "cost_management_contributor_assignment" {
  count     = var.enable_cost_exports && !local.is_mca ? 1 : 0
  name      = uuidv5("dns", "${azuread_service_principal.digiusher_app_sp.object_id}-cost-mgmt-contributor-${md5(local.billing_scope)}")
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = local.billing_scope

  body = {
    properties = {
      principalId      = azuread_service_principal.digiusher_app_sp.object_id
      roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/434105ed-43f6-45c7-a02f-909b2ba83430"
      principalType    = "ServicePrincipal"
    }
  }

  lifecycle {
    ignore_changes = [name]
  }
}

# Billing account contributor role for MCA (required to trigger exports)
# MCA uses a separate billing RBAC system - standard ARM RBAC roles don't apply
resource "azapi_resource_action" "mca_billing_contributor" {
  count       = var.enable_cost_exports && local.is_mca ? 1 : 0
  type        = "Microsoft.Billing/billingAccounts@2024-04-01"
  resource_id = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}"
  action      = "createBillingRoleAssignment"
  method      = "POST"

  body = {
    principalId       = azuread_service_principal.digiusher_app_sp.object_id
    principalTenantId = var.tenant_id
    roleDefinitionId  = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingRoleDefinitions/50000000-aaaa-bbbb-cccc-100000000001"
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
  type      = "Microsoft.CostManagement/exports@2025-03-01"
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
          to   = "2099-12-31T00:00:00Z"
        }
      }
      format = var.export_file_format
      deliveryInfo = {
        destination = {
          type           = "AzureBlob"
          resourceId     = azurerm_storage_account.export_storage[0].id
          container      = var.storage_container_name
          rootFolderPath = var.export_root_path
        }
      }
      definition = {
        type      = "FocusCost"
        timeframe = "MonthToDate"
        dataSet = {
          granularity = "Daily"
        }
      }
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      compressionMode       = "gzip"
      exportDescription     = "DigiUsher FOCUS cost export"
    }
  }

  depends_on = [
    azurerm_resource_provider_registration.cost_management_exports,
    azurerm_storage_container.export_container,
    azurerm_role_assignment.storage_blob_contributor,
    azapi_resource.cost_management_contributor_assignment,
    azapi_resource_action.mca_billing_contributor
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

output "export_name" {
  description = "Name of the FOCUS export"
  value       = var.enable_cost_exports ? azapi_resource.focus_export[0].name : null
}

output "billing_scope" {
  description = "Billing scope used for the export"
  value       = var.enable_cost_exports ? local.billing_scope : null
}

output "billing_scope_type" {
  description = "Detected billing scope type"
  value       = var.enable_cost_exports ? local.billing_scope_type : null
}

output "backfill_command" {
  description = "Command to run historical data backfill (run once per month)"
  value       = var.enable_cost_exports ? "python3 backfill_historical_data.py --tenant-id ${var.tenant_id} --client-id ${azuread_application.digiusher_app.client_id} --billing-scope '${local.billing_scope}' --export-name ${azapi_resource.focus_export[0].name} --month YYYY-MM" : null
}

output "digiusher_onboarding" {
  description = "Values needed for DigiUsher onboarding"
  value = {
    tenant_id              = var.tenant_id
    application_id         = azuread_application.digiusher_app.client_id
    client_secret          = azuread_application_password.app_password.value
    subscription_id        = var.subscription_id
    storage_account_name   = var.enable_cost_exports ? azurerm_storage_account.export_storage[0].name : null
    storage_container_name = var.enable_cost_exports ? var.storage_container_name : null
    export_root_path       = var.enable_cost_exports ? var.export_root_path : null
  }
  sensitive = true
}
