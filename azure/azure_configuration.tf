# Configure the Azure AD provider
terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
      version = "~> 2.36.0"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azuread" {}

# Data source for tenant details
data "azurerm_client_config" "current" {}

variable "subscription_id" {
  type        = string
  description = "The Subscription ID which should be used to create the application"
}

variable "tenant_id" {
  type        = string
  description = "The Tenant ID which should be used"
}

# Variable for explicit subscription IDs
variable "target_subscription_ids" {
  type        = list(string)
  description = "List of specific subscription IDs to target. If empty, all subscriptions will be used."
  default     = []
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Data source for Azure AD client config
data "azuread_client_config" "current" {}

# Get all available subscriptions in the tenant
data "azurerm_subscriptions" "available" {}

locals {
  # Use explicit subscription IDs if provided, otherwise use all subscriptions
  all_subscriptions = [
    for s in data.azurerm_subscriptions.available.subscriptions : s.subscription_id
  ]

  subscriptions = length(var.target_subscription_ids) > 0 ? var.target_subscription_ids : local.all_subscriptions
}

# Create a single application for the tenant
resource "azuread_application" "digiusher_app" {
  display_name = "DigiUsherApp"
  owners       = [data.azuread_client_config.current.object_id]
}

# Create a single service principal
resource "azuread_service_principal" "digiusher_app_sp" {
  application_id             = azuread_application.digiusher_app.application_id
  app_role_assignment_required = false
  owners                     = [data.azuread_client_config.current.object_id]
}

# Create a single secret for the application
resource "azuread_application_password" "app_password" {
  display_name          = "DigiUsherApp Secret"
  application_object_id = azuread_application.digiusher_app.object_id
}

variable "enable_power_scheduler" {
  type        = bool
  description = "If true, adds permissions to start and deallocate (stop) VMs"
  default     = false
}

resource "azurerm_role_definition" "digiusher_power_scheduler" {
  count       = var.enable_power_scheduler ? 1 : 0
  name        = "DigiUsher Power Scheduler"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Custom role for managing VM start/deallocate actions"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

# Assign Reader role to the service principal in each subscription
resource "azurerm_role_assignment" "app_role_assignment" {
  count                = length(local.subscriptions)
  scope                = "/subscriptions/${local.subscriptions[count.index]}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.digiusher_app_sp.object_id
}

# Assign power scheduler role if enabled
resource "azurerm_role_assignment" "digiusher_power_scheduler_role_assignment" {
  count               = var.enable_power_scheduler ? length(local.subscriptions) : 0
  scope               = "/subscriptions/${local.subscriptions[count.index]}"
  role_definition_id  = azurerm_role_definition.digiusher_power_scheduler[0].role_definition_resource_id
  principal_id        = azuread_service_principal.digiusher_app_sp.object_id
}


# https://learn.microsoft.com/en-us/answers/questions/1464207/cannot-assign-reservations-reader-permission-to-a
data "azurerm_role_definition" "reservations_reader" {
  name = "Reservations Reader"
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

output "application_id" {
  description = "The Application ID (Client ID) of the DigiUsher application"
  value       = azuread_application.digiusher_app.application_id
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
