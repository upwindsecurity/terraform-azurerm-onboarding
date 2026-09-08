# SaaS (Provider-Hosted) Onboarding with DSPM Storage-Account Scoping
# Same secretless SaaS onboarding as examples/tenant-saas, with the storage
# data-plane grants (Storage Blob Data Reader / Storage File Data Privileged
# Reader) scoped to an allowlist of storage accounts instead of the broad
# snapshot scopes. The grants back BOTH DSPM and Azure Function code scanning's
# AAD fallback - see the dspm_storage_accounts variable description.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

# See examples/tenant-saas for why Microsoft.Compute must be registered here.
provider "azurerm" {
  subscription_id                 = local.azure_orchestrator_subscription_id
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Compute"]
  features {}
}

provider "azuread" {
  tenant_id = local.azure_tenant_id
}

module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # Upwind organization configuration (no Upwind client credentials needed - SaaS is secretless)
  upwind_organization_id = "org_example12345"

  # SaaS (provider-hosted) onboarding
  saas_enabled           = true
  snapshot_app_client_id = "11111111-1111-1111-1111-111111111111" # Upwind Snapshot app registration
  fetcher_app_client_id  = "22222222-2222-2222-2222-222222222222" # Upwind Fetcher app registration

  customer_snapshot_resource_group = "upwind-cs-rg-org_example12345"

  # Azure configuration - tenant-root scope (roles inherited by all subscriptions)
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id

  # Scope the Snapshot SP's data-plane read grants to these storage accounts only,
  # instead of every snapshot scope. Accounts created after apply are invisible to
  # DSPM and to function scanning's AAD fallback until the list is refreshed;
  # discover candidates with scripts/list-function-storage-accounts.sh. An empty
  # list falls back to the broad scopes - to remove the grants entirely, set
  # upwind_feature_dspm_enabled = false.
  dspm_storage_accounts = [
    "/subscriptions/${local.azure_orchestrator_subscription_id}/resourceGroups/rg-func-payments/providers/Microsoft.Storage/storageAccounts/stfuncpayments001",
    "/subscriptions/${local.azure_orchestrator_subscription_id}/resourceGroups/rg-func-shared/providers/Microsoft.Storage/storageAccounts/stfuncshared001",
  ]

  resource_suffix = "example"
}
