# Management Group-Level Onboarding Example

This example demonstrates scoping monitoring to specific management groups instead of the entire tenant.

## Features

- **Scoping**: Management group level (monitors specific management groups)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_management_group_ids` to scope to specific management groups
- **Does NOT use** `azure_tenant_id` (mutually exclusive with management groups)
- Scanner credentials to enable CloudScanner deployment

## Use Case

Use this approach when you want to:

- Monitor only specific parts of your Azure organization
- Exclude certain management groups from monitoring
- Have granular control over which subscriptions are monitored

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the management group IDs with your actual management group names
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
