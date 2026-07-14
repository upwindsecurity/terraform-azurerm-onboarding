# SaaS (Provider-Hosted) Tenant Onboarding Example - Pre-Created Service Principals

This example demonstrates secretless SaaS (provider-hosted) onboarding at the tenant level
using **pre-created service principals**. Use this variant when the service principals for
Upwind's Snapshot and Fetcher app registrations already exist in the customer tenant (created
out-of-band) and the Terraform runner does **not** have Microsoft Graph permissions to create
them.

For the default flow where the module creates and consents the service principals, see the
[`tenant-saas`](../tenant-saas) example.

## Features

- **Mode**: SaaS / provider-hosted (`saas_enabled = true`)
- **Service principals**: Supplied by object ID — the module skips creation/consent and only assigns roles (no Graph access needed on the runner)
- **Scoping**: Tenant root management group (roles inherited by all subscriptions, current and future)
- **Secrets**: None — the customer tenant holds no app registration, Key Vault, managed identities, custom roles, or scanner credentials
- **Upwind API**: None — no Upwind client credentials are required

## Configuration

This example uses:

- `saas_enabled = true` to select the secretless SaaS path
- `snapshot_app_service_principal_object_id` / `fetcher_app_service_principal_object_id` — the **object IDs** of the pre-created Snapshot and Fetcher service principals in the customer tenant (not the app client IDs)
- `azure_tenant_id` to assign the service principals their scoped roles at the tenant-root management group

> **Object ID, not client ID.** The `*_app_service_principal_object_id` inputs take the service
> principal (enterprise application) object ID in the customer tenant — a different value from the
> app client ID. When supplied, the corresponding `*_app_client_id` input is not required.

The module assigns the two service principals their scoped roles at the tenant-root management
group:

- Snapshot SP (read, at the MG): Reader + a CloudScannerTargetRole custom role + Storage Blob/File data-plane readers
- Snapshot SP (write/delete, confined to the central snapshots RG in the orchestrator subscription): Disk Snapshot Contributor + Data Operator for Managed Disks
- Fetcher SP (at the MG): the built-in read roles (`azure_roles`) + a custom role (`azure_custom_role_permissions`)

The module also creates the central snapshots resource group in the orchestrator subscription
(name from `customer_snapshot_resource_group`, default `upwind-cs-rg-<org-id>`).

No self-hosted resources (app registration, Key Vault, managed identities, custom roles) and no
scanner credentials are created.

## Prerequisites

Pre-create the two service principals in the customer tenant and capture their object IDs, e.g.:

```bash
# Snapshot
az ad sp create --id <snapshot-app-client-id>
az ad sp show   --id <snapshot-app-client-id> --query id -o tsv

# Fetcher
az ad sp create --id <fetcher-app-client-id>
az ad sp show   --id <fetcher-app-client-id> --query id -o tsv
```

(or grant admin consent via the Azure portal, which also materializes the service principals).

## Usage

1. Update the local values with your actual Azure tenant and subscription IDs
2. Replace the Snapshot and Fetcher service principal object IDs with the values from the prerequisites above
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

Note: `terraform destroy` removes the role assignments and definitions this module created. It
does **not** delete the pre-created service principals, since the module did not create them.
