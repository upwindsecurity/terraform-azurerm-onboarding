# DSPM-Scoped Tenant Onboarding Example
# Demonstrates the two controls over the storage data-plane read surface (Storage Blob
# Data Reader / Storage File Data Privileged Reader), which backs BOTH DSPM and Azure
# Function code scanning's AAD fallback:
#   - upwind_feature_dspm_enabled: opt the surface in or out entirely.
#   - dspm_storage_accounts: scope the grants to an allowlist of storage accounts
#     instead of every cloudscanner scope.

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

  # Legacy client-secret flow; see examples/tenant-wif for workload identity federation.
  use_workload_identity_federation = false

  # Upwind organization configuration
  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  # Cloud Scanner credentials
  scanner_client_id     = "scanner_client_id_example"
  scanner_client_secret = "scanner_client_secret_example"

  # Azure configuration - Tenant level scope
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westus"

  # DSPM stays enabled (the default), but the data-plane read grants are scoped to an
  # allowlist of storage accounts instead of every cloudscanner scope. Accounts created
  # after apply are invisible to DSPM and to function scanning's AAD fallback until the
  # list is refreshed and re-applied; discover candidates with
  # scripts/list-function-storage-accounts.sh.
  upwind_feature_dspm_enabled = true
  dspm_storage_accounts = [
    "/subscriptions/${local.azure_orchestrator_subscription_id}/resourceGroups/rg-func-payments/providers/Microsoft.Storage/storageAccounts/stfuncpayments001",
    "/subscriptions/${local.azure_orchestrator_subscription_id}/resourceGroups/rg-func-shared/providers/Microsoft.Storage/storageAccounts/stfuncshared001",
  ]

  # To opt out of the storage data-plane surface entirely (disables DSPM AND degrades
  # Azure Function scanning to key-auth-only), set instead:
  # upwind_feature_dspm_enabled = false

  resource_suffix = "example"
}
