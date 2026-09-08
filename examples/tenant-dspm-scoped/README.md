# DSPM-Scoped Tenant Onboarding Example

This example demonstrates controlling the storage data-plane read surface — the
Storage Blob Data Reader / Storage File Data Privileged Reader grants that back
**both** DSPM and Azure Function code scanning's AAD fallback.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled (deploys cloud scanner infrastructure)
- **DSPM**: Enabled, with the data-plane grants scoped to a storage-account
  allowlist (`dspm_storage_accounts`) instead of every cloudscanner scope

## The two controls

- `upwind_feature_dspm_enabled` (default `true`) — opts the surface in or out
  entirely. Setting it `false` disables DSPM **and** degrades Azure Function
  scanning to key-auth-only (function code is read via the same grants when
  storage shared-key access is disabled).
- `dspm_storage_accounts` — when set, the grants are assigned only on the listed
  storage accounts. Azure RBAC expresses allowlists, not exclusions: to exclude
  a business area, list everything else. Accounts created after apply are not
  covered until the list is refreshed and re-applied; discover candidates with
  `scripts/list-function-storage-accounts.sh`.

`dspm_storage_accounts` replaces the deprecated `function_storage_accounts`
(the new name wins when both are set; conflicting values fail validation).

## Configuration

This example uses placeholder values in `main.tf` locals — replace the tenant ID,
orchestrator subscription ID, credentials, and storage-account resource IDs with
real values before applying.
