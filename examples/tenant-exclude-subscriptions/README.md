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
- The set being excluded from follows the scope: with `azure_tenant_id` (this example) it is every
  subscription in the tenant; with `azure_management_group_ids` and no `azure_tenant_id` it is only
  the subscriptions under those management groups, nested groups included — see
  [tenant-management-groups](../tenant-management-groups/)
- The resulting list **is** the scope. The orchestrator subscription
  (`azure_orchestrator_subscription_id`) is not appended on top of it, so listing the orchestrator
  subscription in `cloudapi_exclude_subscriptions` genuinely excludes it. To keep it covered, leave
  it out of the exclude list

> **Note**
> Before the UP-4303 follow-up, an exclude filter still appended the orchestrator subscription to
> the CloudAPI scope. That re-added it even when it had been explicitly excluded, and under a
> management group scope it placed role assignments on a subscription outside the hierarchy.
> Upgrading removes those assignments on the next apply.

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
