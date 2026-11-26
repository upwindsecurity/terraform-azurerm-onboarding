# SaaS (Provider-Hosted) Onboarding with Azure SQL Managed Instance DSPM
# Same secretless SaaS onboarding as examples/tenant-saas, with Azure SQL Managed
# Instance DSPM turned on. Upwind restores each source database into its own scan
# managed instance in the orchestrator subscription, scans the copy from Upwind's
# tenant, and drops it. Unlike the rest of SaaS onboarding, this creates resources
# in the customer's tenant: the scan resource group, Upwind's roles on it, and
# (with TDE key vaults listed) the scan instances' managed identity.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
  # Subscription holding the TDE key vaults of the source managed instances.
  azure_data_subscription_id = "11111111-2222-3333-4444-555555555555"
}

# See examples/tenant-saas for why Microsoft.Compute must be registered here. The
# Snapshot SP can't register providers either, so also register what the scan
# managed instance (Microsoft.Sql), its network (Microsoft.Network) and the TDE
# identity (Microsoft.ManagedIdentity) need.
provider "azurerm" {
  subscription_id                 = local.azure_orchestrator_subscription_id
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Compute", "Microsoft.Sql", "Microsoft.Network", "Microsoft.ManagedIdentity"]
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

  # Azure SQL MI DSPM needs DSPM on (the default). With no
  # dspm_sql_managed_instances list, the read-only Backup Reader is granted at the
  # snapshot scopes, so instances created later are covered.
  upwind_feature_dspm_enabled                            = true
  upwind_feature_dspm_azure_sql_managed_instance_enabled = true

  # Only for sources whose TDE protector is a customer-managed key; leave it out
  # if all sources use service-managed keys. See examples/tenant-dspm-sql-mi and
  # the module README, "customer-managed TDE keys".
  dspm_sql_tde_key_vault_ids = [
    "/subscriptions/${local.azure_data_subscription_id}/resourceGroups/rg-tde-keys/providers/Microsoft.KeyVault/vaults/kv-sql-tde-2026",
  ]
}
