# Azure SQL Managed Instance DSPM Example (self-hosted)
# Self-hosted onboarding through workload identity federation, with Azure SQL
# Managed Instance DSPM turned on. Upwind never connects to the source instances:
# it restores each database into its own scan managed instance in the
# orchestrator subscription, scans the copy, and drops it.
#   - upwind_feature_dspm_azure_sql_managed_instance_enabled: the opt-in.
#   - dspm_sql_managed_instances: optional; limit restores to these instances.
#   - dspm_sql_tde_key_vault_ids: only for sources on customer-managed TDE keys.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
  # Subscription holding the source managed instances and their TDE key vaults.
  azure_data_subscription_id = "11111111-2222-3333-4444-555555555555"
}

provider "azurerm" {
  subscription_id = local.azure_orchestrator_subscription_id
  # Pinned: azurerm 4.x defaults to "legacy" (which registers Microsoft.KeyVault
  # and the other providers this module uses), 5.x to "none".
  resource_provider_registrations = "legacy"
  # Microsoft.App for CloudScanner. Upwind's principal can't register resource
  # providers, so register what the scan managed instance (Microsoft.Sql), its
  # network (Microsoft.Network) and the TDE identity (Microsoft.ManagedIdentity)
  # need in the orchestrator subscription here.
  resource_providers_to_register = ["Microsoft.App", "Microsoft.Sql", "Microsoft.Network", "Microsoft.ManagedIdentity"]
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
  upwind_organization_id           = "org_example12345"
  use_workload_identity_federation = true
  fetcher_app_client_id            = "33333333-3333-3333-3333-333333333333"

  # Scanner credentials (from the Upwind console). Azure SQL MI DSPM needs
  # CloudScanner in self-hosted mode: its worker scans the restored copies.
  scanner_client_id     = "example-scanner-client-id"
  scanner_client_secret = "example-scanner-client-secret"

  # Azure configuration - tenant level scope
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westeurope"

  # Azure SQL MI DSPM needs DSPM on (the default).
  upwind_feature_dspm_enabled                            = true
  upwind_feature_dspm_azure_sql_managed_instance_enabled = true

  # Optional: grant the read-only Backup Reader on these instances only. Left
  # empty, it is granted at the CloudScanner scopes, so instances created later
  # are covered with no change here, but Upwind can then restore, and so read,
  # any managed instance database under those scopes.
  dspm_sql_managed_instances = [
    "/subscriptions/${local.azure_data_subscription_id}/resourceGroups/rg-sales-data/providers/Microsoft.Sql/managedInstances/sqlmi-sales-prod",
    "/subscriptions/${local.azure_data_subscription_id}/resourceGroups/rg-hr-data/providers/Microsoft.Sql/managedInstances/sqlmi-hr-prod",
  ]

  # Only for sources whose TDE protector is a customer-managed key: the Key
  # Vaults holding those keys. Leave this out if all sources use service-managed
  # keys; no identity is created then. List every vault holding a key a stored
  # backup was made under or still registered on a source: here the current
  # vault, and the one the protector was rotated away from, which restores to
  # older points still need. RBAC vaults only; applying needs the right to
  # assign roles on them. See the module README, "customer-managed TDE keys".
  dspm_sql_tde_key_vault_ids = [
    "/subscriptions/${local.azure_data_subscription_id}/resourceGroups/rg-tde-keys/providers/Microsoft.KeyVault/vaults/kv-sql-tde-2026",
    "/subscriptions/${local.azure_data_subscription_id}/resourceGroups/rg-tde-keys/providers/Microsoft.KeyVault/vaults/kv-sql-tde-2025",
  ]
}
