# SaaS (Provider-Hosted) Tenant Onboarding Example - Pre-Created Service Principals
#
# Same secretless SaaS onboarding as the `tenant-saas` example, but the customer
# supplies EXISTING service principals instead of letting the module create and
# consent them. Provide each SP's object ID (the enterprise-application object ID
# in the customer tenant), not the app client ID. The module then skips creating
# the service principals and only assigns their scoped roles at the tenant-root
# management group - so the Terraform runner needs NO Microsoft Graph permissions.
#
# Pre-create the SPs out-of-band, e.g.:
#   az ad sp create --id <snapshot-app-client-id>
#   az ad sp show   --id <snapshot-app-client-id> --query id -o tsv   # -> object ID
# (or via portal admin consent), then feed the resulting object IDs below.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

provider "azurerm" {
  subscription_id = local.azure_orchestrator_subscription_id
  features {}
}

provider "azuread" {
  tenant_id = local.azure_tenant_id
}

module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # Upwind organization configuration (no Upwind client credentials needed - SaaS is secretless)
  upwind_organization_id = "org_example12345"

  # SaaS (provider-hosted) onboarding using pre-created service principals.
  # These are SP OBJECT IDs in the customer tenant, NOT the app client IDs.
  # When supplied, the module skips creating/consenting the SPs (no Graph access
  # needed) and only assigns their roles; the *_app_client_id inputs are not required.
  saas_enabled                             = true
  snapshot_app_service_principal_object_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" # object ID of the consented Snapshot SP
  fetcher_app_service_principal_object_id  = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" # object ID of the consented Fetcher SP

  # Central snapshots resource group, created in the orchestrator subscription.
  # Snapshot write/delete is confined to this RG (not tenant-wide). Optional -
  # defaults to upwind-cs-rg-<upwind_organization_id> when omitted.
  customer_snapshot_resource_group = "upwind-cs-rg-org_example12345"

  # Azure configuration - tenant-root scope (roles inherited by all subscriptions)
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id

  resource_suffix = "example"
}
