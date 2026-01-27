# Exclude Subscriptions Example

This example demonstrates excluding specific subscriptions from monitoring while monitoring the rest of the tenant.

## Features

- **Scoping**: Exclude subscriptions (monitors entire tenant except specified subscriptions)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_tenant_id` for tenant-level scope
- `cloudapi_exclude_subscriptions` to exclude specific subscriptions from CloudAPI discovery
- `cloudscanner_exclude_subscriptions` to exclude specific subscriptions from CloudScanner
- Mutually exclusive with include subscriptions

## Use Case

Use this approach when you want to:

- Monitor most of your tenant but exclude specific subscriptions
- Exclude test, sandbox, or sensitive subscriptions from monitoring
- Have a default "monitor everything" approach with specific exceptions

## Subscription Scoping Rules

- **CloudAPI**: Discovers and monitors all subscriptions except those excluded
- **CloudScanner**: Scans all subscriptions except those excluded
- Mutually exclusive with include subscriptions
- Can be combined with `azure_tenant_id` or `azure_management_group_ids`

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the subscription IDs with the subscriptions you want to exclude
3. Replace the Upwind credentials with your actual values
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
