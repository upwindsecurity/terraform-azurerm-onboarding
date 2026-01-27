# Include Subscriptions Example

This example demonstrates explicitly including specific subscriptions for monitoring.

## Features

- **Scoping**: Include subscriptions (only monitors specified subscriptions)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_tenant_id` for tenant-level scope
- `cloudapi_include_subscriptions` to limit CloudAPI discovery to specific subscriptions
- `cloudscanner_include_subscriptions` to limit CloudScanner to specific subscriptions
- **Important**: CloudScanner scope should be a subset of CloudAPI scope

## Use Case

Use this approach when you want to:

- Monitor only specific subscriptions within a tenant or management group
- Start with a limited scope and expand later
- Have precise control over which subscriptions are monitored and scanned

## Subscription Scoping Rules

- **CloudAPI**: Discovers and monitors resources in specified subscriptions
- **CloudScanner**: Actively scans resources in specified subscriptions
- CloudScanner subscriptions should be a subset of CloudAPI subscriptions
- Mutually exclusive with exclude subscriptions

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the subscription IDs with your actual subscription IDs
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
