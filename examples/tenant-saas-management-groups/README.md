# SaaS (Provider-Hosted) Management Group Onboarding Example

This example demonstrates secretless SaaS (provider-hosted) onboarding scoped to specific
**management groups** rather than the whole tenant. It is the management group counterpart to
[tenant-saas](../tenant-saas/) (tenant scope) and the subscription scope option documented there.

## Features

- **Mode**: SaaS / provider-hosted (`saas_enabled = true`)
- **Scoping**: Management group — `azure_management_group_ids` set, `azure_tenant_id` **not** set
- **Secrets**: None — the customer tenant holds no app registration, Key Vault, managed identities, custom roles, or scanner credentials
- **Upwind API**: None — no Upwind client credentials are required

## Why the management group specific version

Set `azure_tenant_id` and the module scopes everything to the tenant-root management group; any
exclude filter is then expanded against **every subscription in the tenant**. That needs RBAC admin
at the tenant root and reaches subscriptions the onboarding was never meant to touch.

Omitting `azure_tenant_id` and passing `azure_management_group_ids` keeps the onboarding inside the
named hierarchy:

- Role assignments land on those management groups only
- `cloudapi_exclude_subscriptions` / `cloudscanner_exclude_subscriptions` are expanded against the
  subscriptions **under those management groups** (nested groups included, via
  `azurerm_management_group.all_subscription_ids`) — the tenant-wide subscription list is not read
  at all
- The runner needs permission on the management groups and the orchestrator subscription, not on
  the tenant root

Use it when a management group — not the tenant — is the unit you are allowed to onboard.

## Configuration

This example uses:

- `saas_enabled = true` to select the secretless SaaS path
- `snapshot_app_client_id` / `fetcher_app_client_id` — the client IDs of Upwind's multi-tenant Snapshot and Fetcher app registrations
- `azure_management_group_ids` for the scope, with `azure_tenant_id` deliberately omitted from the module call
  (it is still set on the `azuread` provider)

The module materializes the service principals for Upwind's Snapshot and Fetcher app registrations
in the customer tenant and assigns them scoped roles:

- Snapshot SP (read, at each management group): Reader + a CloudScannerTargetRole custom role +
  Storage Blob/File data-plane readers
- Snapshot SP (write/delete, confined to the central snapshots RG in the orchestrator subscription):
  Disk Snapshot Contributor + Data Operator for Managed Disks
- Fetcher SP (at each management group): the built-in read roles (`azure_roles`) + a custom role
  (`azure_custom_role_permissions`)

In SaaS mode both service principals are granted roles at the management groups and nowhere else —
unlike the outpost path, the orchestrator subscription is not added as an extra role-assignment
scope. The central snapshots resource group is created there by the Terraform runner's own
credentials, and the Snapshot SP's write/delete roles are scoped to that resource group. So if the
orchestrator subscription sits outside the management groups, it is not inventoried or scanned —
add it to `azure_management_group_ids`' hierarchy, or name it in the `cloudapi_*` filters, if you
want it covered.

No self-hosted resources (app registration, Key Vault, managed identities, custom roles) and no
scanner credentials are created.

## Scope options

| Scope | Configuration | Exclude filters expand against |
|-------|---------------|--------------------------------|
| Tenant | `azure_tenant_id` set — [tenant-saas](../tenant-saas/) | All tenant subscriptions |
| Management group (this example) | `azure_management_group_ids` set, `azure_tenant_id` unset | Subscriptions under those management groups |
| Subscription | `cloudapi_include_subscriptions` / `cloudscanner_include_subscriptions` set — see [tenant-saas](../tenant-saas/) | N/A — the listed subscriptions are the scope |

The Snapshot SP (scanning) follows the `cloudscanner_*` filters; the Fetcher SP (inventory) follows
the `cloudapi_*` filters. Regardless of scope, snapshot **write/delete** is always confined to the
central snapshots RG in the orchestrator subscription (`customer_snapshot_resource_group`).

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

1. Replace the management group names with your own (names, not full resource IDs)
2. Update the local values with your actual Azure tenant and orchestrator subscription IDs
3. Replace the Snapshot and Fetcher app registration client IDs with the values provided by Upwind
4. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Clean Up

```bash
terraform destroy
```
