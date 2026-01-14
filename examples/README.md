# Terraform Azure Onboarding Examples

This directory contains comprehensive examples demonstrating various configurations of the Azure tenant onboarding module.

## Overview

The examples are organized by use case and feature combinations. Each example is self-contained with its own README
explaining the specific configuration and use case.

## Quick Start

For most users, start with:

- **[tenant-basic](tenant-basic/)** - Simple tenant-level onboarding with CloudScanner

## Examples by Category

### Scoping Examples

Control which parts of your Azure environment are monitored:

- **[tenant-basic](tenant-basic/)** - Monitor entire Azure tenant
- **[tenant-management-groups](tenant-management-groups/)** - Monitor specific management groups
- **[tenant-include-subscriptions](tenant-include-subscriptions/)** - Monitor only specified subscriptions
- **[tenant-exclude-subscriptions](tenant-exclude-subscriptions/)** - Monitor all except specified subscriptions

### CloudScanner Examples

Choose whether to deploy active scanning infrastructure:

- **[tenant-basic](tenant-basic/)** - With CloudScanner (recommended)
- **[tenant-no-cloudscanner](tenant-no-cloudscanner/)** - Discovery only, no CloudScanner

### Feature Examples

Additional configuration options:

- **[tenant-with-tags](tenant-with-tags/)** - Apply custom tags to all resources
- **[tenant-keyvault-deny](tenant-keyvault-deny/)** - Secure Key Vault with network restrictions

### Advanced Examples

Production-ready configurations:

- **[tenant-advanced](tenant-advanced/)** - Combines multiple features (exclusions, tags, Key Vault security)

## Feature Matrix

| Example | Scoping | CloudScanner | Tags | Key Vault | Use Case |
|---------|---------|--------------|------|-----------|----------|
| [tenant-basic](tenant-basic/) | Tenant | ✅ | ❌ | Allow | Getting started |
| [tenant-management-groups](tenant-management-groups/) | Mgmt Groups | ✅ | ❌ | Allow | Partial tenant monitoring |
| [tenant-include-subscriptions](tenant-include-subscriptions/) | Include Subs | ✅ | ❌ | Allow | Specific subscriptions only |
| [tenant-exclude-subscriptions](tenant-exclude-subscriptions/) | Exclude Subs | ✅ | ❌ | Allow | Exclude test/sandbox |
| [tenant-no-cloudscanner](tenant-no-cloudscanner/) | Tenant | ❌ | ❌ | N/A | Discovery only |
| [tenant-with-tags](tenant-with-tags/) | Tenant | ✅ | ✅ | Allow | Compliance/cost tracking |
| [tenant-keyvault-deny](tenant-keyvault-deny/) | Tenant | ✅ | ❌ | Deny | Enhanced security |
| [tenant-advanced](tenant-advanced/) | Exclude Subs | ✅ | ✅ | Deny | Production deployment |

## Choosing an Example

### By Use Case

**Just getting started?**
→ Start with [tenant-basic](tenant-basic/)

**Need to monitor only specific parts of your tenant?**
→ Use [tenant-management-groups](tenant-management-groups/) or [tenant-include-subscriptions](tenant-include-subscriptions/)

**Want to exclude test/sandbox subscriptions?**
→ Use [tenant-exclude-subscriptions](tenant-exclude-subscriptions/)

**Discovery only, no active scanning?**
→ Use [tenant-no-cloudscanner](tenant-no-cloudscanner/)

**Need compliance tagging or cost tracking?**
→ Use [tenant-with-tags](tenant-with-tags/)

**Security requirements for Key Vault?**
→ Use [tenant-keyvault-deny](tenant-keyvault-deny/)

**Production deployment with multiple features?**
→ Use [tenant-advanced](tenant-advanced/)

### By Security Posture

**Standard Security:**

- [tenant-basic](tenant-basic/)
- [tenant-management-groups](tenant-management-groups/)
- [tenant-include-subscriptions](tenant-include-subscriptions/)

**Enhanced Security:**

- [tenant-keyvault-deny](tenant-keyvault-deny/)
- [tenant-advanced](tenant-advanced/)

**Minimal Footprint:**

- [tenant-no-cloudscanner](tenant-no-cloudscanner/)

## Common Configuration Patterns

### Tenant-Level Monitoring

```hcl
azure_tenant_id = "12345678-1234-1234-1234-123456789012"
```

### Management Group Monitoring

```hcl
azure_management_group_ids = ["prod-mg", "dev-mg"]
# Do NOT set azure_tenant_id when using management groups
```

### Subscription Filtering

```hcl
# Include specific subscriptions
cloudapi_include_subscriptions = ["sub-id-1", "sub-id-2"]
cloudscanner_include_subscriptions = ["sub-id-1"]

# OR exclude specific subscriptions (mutually exclusive)
cloudapi_exclude_subscriptions = ["sandbox-sub-id"]
cloudscanner_exclude_subscriptions = ["sandbox-sub-id"]
```

### CloudScanner Control

```hcl
# Enable CloudScanner
scanner_client_id     = "scanner_client_id"
scanner_client_secret = "scanner_client_secret"

# Disable CloudScanner - omit scanner credentials
# scanner_client_id     = ""
# scanner_client_secret = ""
```

### Custom Tags

```hcl
tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "Security-Team"
  CostCenter  = "IT-Security"
}
```

### Key Vault Security

```hcl
key_vault_deny_traffic = true
key_vault_ip_rules = [
  "203.0.113.42",      # Your IP
  "198.51.100.0/24"    # Office network
]
```

## Prerequisites

All examples require:

- Terraform >= 1.2
- Azure CLI authenticated
- Appropriate Azure permissions (see module documentation)
- Upwind organization credentials
- (Optional) CloudScanner credentials for active scanning

## Usage

1. Choose an example that matches your use case
2. Navigate to the example directory
3. Copy the example and customize:
   - Update Azure tenant/subscription IDs
   - Replace Upwind credentials
   - Adjust configuration as needed
4. Run Terraform:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Module Documentation

For detailed module documentation, see:

- [Tenant Module](../modules/tenant/)
- [Tenant Onboarding Matrix](../TENANT_MATRIX.md)

## Support

For issues or questions:

- Check the example README for specific guidance
- Review the module documentation
- Contact Upwind support

## Legacy Examples

The following directories contain legacy or environment-specific examples:

- `cloudscanner-dev/` - Development environment examples
- `cloudscanner-dev-eu/` - EU development environment examples
- `subscription/` - Subscription-level onboarding (deprecated)
- `upwind-labs-*/` - Internal testing examples

For new deployments, use the examples listed above.
