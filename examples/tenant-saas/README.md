# SaaS (Provider-Hosted) Tenant Onboarding Example

This example demonstrates secretless SaaS (provider-hosted) onboarding at the tenant level.

## Features

- **Mode**: SaaS / provider-hosted (`saas_enabled = true`)
- **Scoping**: Tenant root management group (roles inherited by all subscriptions, current and future)
- **Secrets**: None — the customer tenant holds no app registration, Key Vault, managed identities, custom roles, or scanner credentials
- **Upwind API**: None — no Upwind client credentials are required

## Configuration

This example uses:

- `saas_enabled = true` to select the secretless SaaS path
- `snapshot_app_client_id` / `fetcher_app_client_id` — the client IDs of Upwind's multi-tenant Snapshot and Fetcher app registrations
- `azure_tenant_id` to assign the consented service principals their scoped roles at the tenant-root management group

In SaaS mode the module materializes the service principals for Upwind's Snapshot and Fetcher
app registrations in the customer tenant and assigns them scoped roles at the tenant-root
management group:

- Snapshot SP: Reader + Disk Snapshot Contributor + Data Operator for Managed Disks
- Fetcher SP: Reader

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
