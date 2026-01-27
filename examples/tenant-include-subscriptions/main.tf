# Include Subscriptions Example
# This example demonstrates explicitly including specific subscriptions for monitoring.

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

  # Azure configuration - Tenant level with subscription filtering
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westus"

  # Include specific subscriptions for CloudAPI (discovery)
  cloudapi_include_subscriptions = [
    "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
    "b1d08fc6-491d-5db1-9878-10e27bde98b"
  ]

  # Include specific subscriptions for CloudScanner (scanning)
  # CloudScanner scope should be a subset of CloudAPI scope
  cloudscanner_include_subscriptions = [
    "a9c07ec5-380c-4ca0-8767-09d16acfd87a"
  ]

  resource_suffix = "example"
}
