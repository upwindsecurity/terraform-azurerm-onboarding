# SaaS (Provider-Hosted) Tenant Onboarding Example

This example demonstrates secretless SaaS (provider-hosted) onboarding at the tenant level.

## Features

- **Mode**: SaaS / provider-hosted (`saas_enabled = true`)
- **Scoping**: Tenant, Management Group, or Subscription — same three options as the outpost path (this example uses Tenant)
- **Secrets**: None — the customer tenant holds no app registration, Key Vault, managed identities, custom roles, or scanner credentials
- **Upwind API**: None — no Upwind client credentials are required

## Scope options

SaaS supports the same three scoping options as the self-hosted (outpost) path. Pick one:

```hcl
# 1. Tenant (this example) — roles at the tenant-root management group, inherited by all subscriptions
azure_tenant_id = "12345678-1234-1234-1234-123456789012"

# 2. Management group — roles at specific management group(s)
azure_management_group_ids = ["prod-mg", "dev-mg"]   # do NOT set azure_tenant_id

# 3. Subscription — roles scoped to specific subscriptions only
azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
cloudapi_include_subscriptions     = ["<sub-id>"]   # Fetcher (inventory) scope
cloudscanner_include_subscriptions = ["<sub-id>"]   # Snapshot (scanning) scope
```

The Snapshot SP (scanning) follows the `cloudscanner_*` filters; the Fetcher SP (inventory) follows
the `cloudapi_*` filters. Regardless of scope, snapshot **write/delete** is always confined to the
central snapshots RG in the orchestrator subscription (`customer_snapshot_resource_group`). Use the
subscription option when the runner has RBAC-admin only on specific subscriptions, not the tenant/MG.

## Configuration

This example uses:

- `saas_enabled = true` to select the secretless SaaS path
- `snapshot_app_client_id` / `fetcher_app_client_id` — the client IDs of Upwind's multi-tenant Snapshot and Fetcher app registrations
- `azure_tenant_id` to assign the consented service principals their scoped roles at the tenant-root management group

In SaaS mode the module materializes the service principals for Upwind's Snapshot and Fetcher
app registrations in the customer tenant and assigns them scoped roles:

- Snapshot SP (read, at the tenant-root management group): Reader + a CloudScannerTargetRole
  custom role + Storage Blob/File data-plane readers
- Snapshot SP (write/delete, confined to the central snapshots RG in the orchestrator
  subscription): Disk Snapshot Contributor + Data Operator for Managed Disks
- Fetcher SP (at the tenant-root management group): the built-in read roles (`azure_roles`) + a
  custom role (`azure_custom_role_permissions`)

The module also creates the central snapshots resource group in the orchestrator subscription
(name from `customer_snapshot_resource_group`, default `upwind-cs-rg-<org-id>`) — snapshot
write/delete is confined to it rather than granted tenant-wide.

No self-hosted resources (app registration, Key Vault, managed identities, custom roles) and no
scanner credentials are created.

## Usage

1. Update the local values with your actual Azure tenant and subscription IDs
2. Replace the Snapshot and Fetcher app registration client IDs with the values provided by Upwind
3. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Clean Up

```bash
terraform destroy
```
