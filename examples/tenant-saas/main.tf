# SaaS (Provider-Hosted) Tenant Onboarding Example
# Secretless: the customer tenant only consents to Upwind's multi-tenant Snapshot
# and Fetcher app registrations and assigns them scoped roles at the tenant-root
# management group. No app registration, Key Vault, managed identities, custom
# roles, scanner credentials, or Upwind API calls are created.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

# Microsoft.Compute must be registered in the orchestrator subscription. The Snapshot SP
# writes Microsoft.Compute/snapshots into the central snapshots RG, and its role set
# (Reader, Disk Snapshot Contributor, Data Operator for Managed Disks, CloudScannerTargetRole)
# carries no */register/action - so it cannot register the provider itself, and the first
# snapshot fails with MissingSubscriptionRegistration on an orchestrator subscription that has
# never held a VM. The outpost path never needed this: its deployer role holds
# Microsoft.Compute/* and provisions through an ARM deployment, either of which registers the
# provider on first deploy.
#
# resource_provider_registrations is pinned so the registered set is the same on every azurerm
# version - it defaults to "legacy" (~60 providers, each needing register/action) on 4.x and to
# "none" on 5.x. Nothing else is needed here: this path only creates a resource group and role
# definitions, under Microsoft.Resources / Microsoft.Authorization, which are always registered.
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

  # Central snapshots resource group, created in the orchestrator subscription.
  # Snapshot write/delete is confined to this RG (not tenant-wide). Optional -
  # defaults to upwind-cs-rg-<upwind_organization_id> when omitted.
  customer_snapshot_resource_group = "upwind-cs-rg-org_example12345"

  # Azure configuration - tenant-root scope (roles inherited by all subscriptions)
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id

  resource_suffix = "example"
}
