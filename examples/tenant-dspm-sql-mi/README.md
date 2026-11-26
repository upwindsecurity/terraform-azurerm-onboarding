# Azure SQL Managed Instance DSPM Tenant Onboarding Example

This example turns on Azure SQL Managed Instance DSPM in a self-hosted onboarding (workload identity federation).
Upwind never connects to your production instances: it restores each database into its own scan managed instance in
the orchestrator subscription, scans the copy with the CloudScanner worker, and drops it.

## Features

- **Scoping**: Tenant level
- **CloudScanner**: Enabled (required: the worker scans the restored copies)
- **Azure SQL MI DSPM**: Enabled, with the read-only Backup Reader limited to two listed instances
  (`dspm_sql_managed_instances`) and key access for sources on customer-managed TDE keys
  (`dspm_sql_tde_key_vault_ids`)

## What it creates for Azure SQL MI DSPM

- The resource group `upwind-cs-sqlmi-rg-<orgId>` in the orchestrator subscription, for the scan instances and their
  network, which Upwind creates on the first scan in each region.
- Upwind's roles on that resource group (create, start, stop and restore onto the scan instance; build its network),
  plus a join-only role for the worker's network.
- A read-only Backup Reader on each listed source instance.
- Because TDE key vaults are listed: the scan instances' identity, `upwind-cs-sqlmi-scan-identity-<orgId>`, with
  Key Vault Crypto Service Encryption User on each listed vault.

## The three inputs

- `upwind_feature_dspm_azure_sql_managed_instance_enabled` turns the feature on. It also needs DSPM on
  (`upwind_feature_dspm_enabled`, the default) and CloudScanner.
- `dspm_sql_managed_instances` (optional) limits the Backup Reader to the listed instances. Left out, it is granted at
  the CloudScanner scopes, so instances created later are covered, but Upwind can then restore, and so read, any
  managed instance database under those scopes.
- `dspm_sql_tde_key_vault_ids` is only for sources whose TDE protector is a customer-managed key. Leave it out if all
  sources use service-managed keys: no identity is created then. List every vault holding a key that a stored backup
  was made under or that is still registered on a source, which after a key rotation includes the previous vault, as
  here. The vaults must use the Azure RBAC permission model, and applying needs the right to assign roles on them. See
  the module README, "customer-managed TDE keys", for the full rules.

## Resource providers

Upwind's principal can't register resource providers, so the provider block registers `Microsoft.Sql`,
`Microsoft.Network` and `Microsoft.ManagedIdentity` in the orchestrator subscription. The account running Terraform
needs the right to register them (Contributor or Owner on the subscription covers it).

## Turning it off

Offboard the scanners in Upwind first: that deletes the scan instances and their network. Then set
`upwind_feature_dspm_azure_sql_managed_instance_enabled = false`. The plan warns if a scan instance is still there.
With `prevent_deletion_if_contains_resources = false`, as here, applying anyway deletes the resource group with
everything in it.

## Configuration

This example uses placeholder values in `main.tf` locals and inputs. Replace the tenant ID, subscription IDs, app and
scanner credentials, managed instance IDs and Key Vault IDs with real values before applying.
