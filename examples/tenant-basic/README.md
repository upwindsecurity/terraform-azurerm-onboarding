# Basic Tenant-Level Onboarding Example

This example demonstrates the simplest tenant onboarding configuration.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled (deploys cloud scanner infrastructure)
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_tenant_id` to scope monitoring to the entire tenant
- Scanner credentials to enable CloudScanner deployment
- Default Key Vault network settings (allows traffic)

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the Upwind credentials with your actual values
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
