# Management Group-Level Onboarding Example
# This example demonstrates scoping to specific management groups instead of the entire tenant.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

provider "azurerm" {
  subscription_id                = local.azure_orchestrator_subscription_id
  resource_providers_to_register = ["Microsoft.App"]
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      recover_soft_deleted_keys       = true
      recover_soft_deleted_secrets    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
  tenant_id = local.azure_tenant_id
}

module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # Upwind organization configuration
  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  # Cloud Scanner credentials
  scanner_client_id     = "scanner_client_id_example"
  scanner_client_secret = "scanner_client_secret_example"

  # Azure configuration - Management group level scope
  # Note: azure_tenant_id is NOT set, using management groups instead
  azure_management_group_ids = [
    "production-mg",
    "development-mg"
  ]
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westus"

  resource_suffix = "example"
}
