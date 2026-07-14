# Tenant Onboarding With A Private Networking Key Vault
# This example provisions the CloudScanner Key Vault with public network access fully
# disabled. Because Terraform cannot reach a private vault to write secrets, the scanner
# credentials must be added to the vault manually after apply (see the notes below).

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

  # Azure configuration - Tenant level scope
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westus"

  # Private networking Key Vault.
  # Public network access is disabled and Terraform does NOT create the scanner secrets -
  # you must add 'upwind-client-id' and 'upwind-client-secret' to the vault yourself.
  # Note: scanner_client_id / scanner_client_secret are intentionally omitted; they would
  # be unreachable to write and are supplied manually instead.
  key_vault_private_network = true

  resource_suffix = "example"
}
