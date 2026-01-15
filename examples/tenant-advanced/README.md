# Advanced Tenant Onboarding Example

This example demonstrates a production-ready configuration combining multiple features.

## Features

- **Scoping**: Tenant level with subscription exclusions
- **CloudScanner**: Enabled
- **Tags**: Custom tags for compliance and cost tracking
- **Key Vault**: Network restrictions with IP allowlist
- **Resource Suffix**: Custom suffix for unique resource naming

## Configuration Highlights

This example combines:

- Tenant-level monitoring with excluded subscriptions
- CloudScanner deployment for active scanning
- Custom tags for organizational compliance
- Secured Key Vault with network ACLs
- Production-ready naming conventions

## Use Case

This configuration is ideal for:

- Production environments requiring enhanced security
- Organizations with compliance requirements (SOC2, HIPAA, etc.)
- Teams needing cost tracking and resource tagging
- Deployments requiring network-restricted Key Vault access
- Multi-environment setups (prod, staging, dev)

## Security Features

### Network Security

- Key Vault restricted to specific IP addresses
- Service endpoints for CloudScanner subnet access
- Azure trusted services allowed

### Compliance

- Custom tags for audit trails
- Resource naming with environment suffix
- Subscription-level exclusions for sensitive workloads

### Best Practices

- Excludes test/sandbox subscriptions from monitoring
- Applies consistent tagging across all resources
- Uses network restrictions on Key Vault
- Follows least-privilege access principles

## Configuration Details

### Excluded Subscriptions

Sandbox and test subscriptions are excluded from both CloudAPI and CloudScanner to:

- Reduce noise in monitoring
- Lower costs by not scanning non-production resources
- Maintain separation between environments

### Custom Tags

Tags are applied for:

- **Environment**: Identify production vs non-production
- **ManagedBy**: Track infrastructure-as-code management
- **Owner**: Assign responsibility
- **CostCenter**: Enable cost allocation
- **Project**: Group related resources
- **Compliance**: Track compliance requirements

### Key Vault Security

Network ACLs restrict access to:

- Specified public IP addresses
- Office network CIDR blocks
- Azure trusted services (automatic)
- CloudScanner subnet (via service endpoint)

## Usage

1. Update the local values:
   - `azure_tenant_id`: Your Azure tenant ID
   - `azure_orchestrator_subscription_id`: Subscription for Upwind infrastructure
   - `my_public_ip`: Your public IP address

2. Customize exclusions:
   - Update `cloudapi_exclude_subscriptions` with subscriptions to exclude
   - Update `cloudscanner_exclude_subscriptions` accordingly

3. Customize tags:
   - Modify tags to match your organization's policies
   - Add or remove tags as needed

4. Update Key Vault IP rules:
   - Set your public IP address
   - Add office network CIDR blocks
   - Include any other required IP ranges

5. Replace Upwind credentials with actual values

6. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Validation

After deployment, verify:

- [ ] All expected subscriptions are monitored
- [ ] Excluded subscriptions are not monitored
- [ ] Tags are applied to all resources
- [ ] Key Vault is accessible from allowed IPs only
- [ ] CloudScanner is deployed and running

## Clean Up

```bash
terraform destroy
```

## Related Examples

- [tenant-basic](../tenant-basic/) - Simple tenant onboarding
- [tenant-exclude-subscriptions](../tenant-exclude-subscriptions/) - Subscription exclusions
- [tenant-with-tags](../tenant-with-tags/) - Custom tagging
- [tenant-keyvault-deny](../tenant-keyvault-deny/) - Key Vault security
