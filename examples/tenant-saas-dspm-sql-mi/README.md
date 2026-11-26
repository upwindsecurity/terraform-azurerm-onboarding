# SaaS Onboarding with Azure SQL Managed Instance DSPM Example

This example turns on Azure SQL Managed Instance DSPM in SaaS (provider-hosted) onboarding. Upwind restores each
source database into its own scan managed instance in the orchestrator subscription, scans the copy from Upwind's
tenant, and drops it.

## Features

- **Scoping**: Tenant level (tenant-root management group)
- **CloudScanner**: Provider-hosted (no customer-side scanner)
- **Azure SQL MI DSPM**: Enabled, with the read-only Backup Reader at the snapshot scopes (no instance list) and key
  access for sources on a customer-managed TDE key (`dspm_sql_tde_key_vault_ids`)

## What it creates in your tenant

Unlike the rest of SaaS onboarding, Azure SQL MI DSPM creates resources in your tenant, because the scan instances run
in your orchestrator subscription:

- the resource group `upwind-cs-sqlmi-rg-<orgId>` and the Snapshot app's roles on it;
- a read-only Backup Reader for the Snapshot app at the snapshot scopes;
- because a TDE key vault is listed: the scan instances' identity, `upwind-cs-sqlmi-scan-identity-<orgId>`, with Key
  Vault Crypto Service Encryption User on the vault. Leave the list out if all sources use service-managed keys: no
  identity is created then.

The private endpoint the worker uses lives in Upwind's subscription, not yours.

## Resource providers

The Snapshot app can't register resource providers, so the provider block registers `Microsoft.Sql`,
`Microsoft.Network` and `Microsoft.ManagedIdentity` in the orchestrator subscription, as well as `Microsoft.Compute`
(see examples/tenant-saas). The account running Terraform needs the right to register them.

## Configuration

This example uses placeholder values in `main.tf` locals and inputs. Replace the tenant ID, subscription IDs, app
registration client IDs and Key Vault IDs with real values before applying. See examples/tenant-dspm-sql-mi and the
module README, "customer-managed TDE keys", for which vaults to list and the requirements on them.
