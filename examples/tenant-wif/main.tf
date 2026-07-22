# Workload Identity Federation (WIF) Tenant Onboarding Example
# Secretless self-hosted onboarding (UP-3278): no app registration, client
# secret, or Upwind API credentials in this tenant. The auth identity is the
# org's Upwind-minted WIF app registration (created when the Azure organization
# is added in the Upwind console); this tenant only materializes its consented
# service principal and grants it the standard self-hosted role set. All other
# self-hosted resources (Key Vault, managed identities, scanner roles) are
# created as usual.

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

  # Upwind organization configuration (no Upwind API credentials needed - WIF is secretless)
  upwind_organization_id = "org_example12345"

  # Workload identity federation (default true; shown here for clarity).
  # fetcher_app_client_id is the org's Upwind-minted WIF (Fetcher) app
  # registration, shown in the Upwind console after the Azure organization is
  # added - the same input the SaaS mode uses. If the Terraform runner lacks
  # Microsoft Graph permissions to create service principals, pre-consent the
  # app and supply fetcher_app_service_principal_object_id instead.
  use_workload_identity_federation = true
  fetcher_app_client_id            = "33333333-3333-3333-3333-333333333333"

  # Azure configuration
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id

  # Scanner credentials (from the Upwind console) still apply as in any
  # self-hosted onboarding - they authenticate the scanner to Upwind, not Azure.
  scanner_client_id     = "example-scanner-client-id"
  scanner_client_secret = "example-scanner-client-secret"
}
