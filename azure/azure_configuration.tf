# Configure the Azure AD provider
terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
      version = "~> 2.36.0"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
}

# Data source for Azure AD client config
data "azuread_client_config" "current" {}

# Prompt user for subscription IDs
variable "subscription_ids" {}

# Load subscription IDs from the .tfvars file
locals {
  subscriptions = var.subscription_ids != null ? var.subscription_ids : []
}

# Iterate over each subscription ID to create resources
resource "azuread_application" "digiusher_app" {
  count        = length(local.subscriptions)
  display_name = "DigiUsherApp-${local.subscriptions[count.index]}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "digiusher_app_sp" {
  count                      = length(local.subscriptions)
  application_id             = azuread_application.digiusher_app[count.index].application_id
  app_role_assignment_required = false
  owners                     = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "app_password" {
  count                 = length(local.subscriptions)
  display_name          = "DigiUsherApp Secret-${local.subscriptions[count.index]}"
  application_object_id = azuread_application.digiusher_app[count.index].object_id
}

resource "azurerm_role_assignment" "app_role_assignment" {
  count                = length(local.subscriptions)
  scope                = "/subscriptions/${local.subscriptions[count.index]}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.digiusher_app_sp[count.index].object_id
}

output "app_info" {
  value = [
      for idx, app in azuread_application.digiusher_app : {
        subscription_id = local.subscriptions[idx]
        application_id = app.application_id
        tenant_id      = data.azuread_client_config.current.tenant_id
        secret         = azuread_application_password.app_password[idx].value
      }
  ]
  depends_on = [azurerm_role_assignment.app_role_assignment]
  sensitive = true
}
