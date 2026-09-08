# SaaS Onboarding with DSPM Storage-Account Scoping

Same secretless SaaS (provider-hosted) onboarding as [tenant-saas](../tenant-saas/),
with the storage data-plane read grants scoped to an allowlist of storage accounts.

## What changes

By default the Snapshot SP receives Storage Blob Data Reader and Storage File Data
Privileged Reader across every snapshot scope (management-group level). With
`dspm_storage_accounts` set, those two grants are assigned **only on the listed
storage accounts** — the RBAC-auditable guarantee that Upwind's data-plane read
cannot reach anything else. All other roles are unaffected.

## Caveats

- The grants back **both** DSPM and Azure Function code scanning's AAD fallback:
  in tenants that disable storage shared-key access by policy, function apps whose
  storage account is unlisted cannot be function-scanned.
- Azure RBAC expresses allowlists, not exclusions — to exclude a business area,
  list everything else.
- The allowlist is a point-in-time snapshot of the estate: accounts created later
  are not covered until the list is refreshed and re-applied. Discover candidates
  with `scripts/list-function-storage-accounts.sh`.
- An empty list is treated as unset (broad scopes). To remove the grants entirely,
  set `upwind_feature_dspm_enabled = false`.

## Configuration

Placeholder values in `main.tf` locals — replace the tenant ID, orchestrator
subscription ID, app registration client IDs, and storage-account resource IDs
before applying.
