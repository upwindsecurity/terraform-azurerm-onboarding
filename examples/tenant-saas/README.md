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
#    Full example: ../tenant-saas-management-groups
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

Under the management group option nothing reaches outside the named hierarchy: the exclude filters
are expanded against the subscriptions under those management groups (nested groups included), not
the tenant-wide subscription list. See
[tenant-saas-management-groups](../tenant-saas-management-groups/).

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

## Resource provider registration

The `azurerm` provider block registers `Microsoft.Compute` in the orchestrator subscription. The
Snapshot SP creates `Microsoft.Compute/snapshots` in the central snapshots RG, and none of the roles
it is granted carry `*/register/action` - so it cannot register the provider itself, and on an
orchestrator subscription that has never held a VM the first snapshot fails with
`MissingSubscriptionRegistration`. Registration is idempotent: on a subscription where Compute is
already registered this is a no-op.

The principal running `terraform apply` therefore needs `Microsoft.Compute/register/action` on the
orchestrator subscription. Creating the central snapshots resource group already requires
subscription-level write there, so Contributor covers both - only a narrowly-scoped custom role
needs it added. To keep registration out of band instead, pre-register the provider and remove
`resource_providers_to_register` from the provider block.

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
