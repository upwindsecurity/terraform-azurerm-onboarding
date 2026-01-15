# Tenant Onboarding With Custom Tags

This example demonstrates applying custom tags to all deployed Upwind resources.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled
- **Tags**: Custom tags applied to all resources
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_tenant_id` to scope monitoring to the entire tenant
- `tags` variable to apply custom tags to all deployed resources
- Scanner credentials to enable CloudScanner deployment

## Use Case

Use this approach when you want to:

- Apply consistent tagging across all Upwind infrastructure
- Track costs by project, team, or cost center
- Comply with organizational tagging policies
- Identify resources by environment, owner, or purpose

## Tagged Resources

The tags will be applied to:

- Resource groups
- Key Vault
- Container App Environment
- Managed identities
- All other Azure resources created by the module

## Common Tag Examples

```hcl
tags = {
  # Environment identification
  Environment = "Production"

  # Ownership and management
  ManagedBy   = "Terraform"
  Owner       = "Security-Team"

  # Cost tracking
  CostCenter  = "IT-Security"
  Project     = "Upwind-Integration"

  # Compliance
  Compliance  = "SOC2"
  DataClass   = "Internal"
}
```

## Usage

1. Update the local values with your actual Azure IDs
2. Customize the tags to match your organization's tagging policy
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
