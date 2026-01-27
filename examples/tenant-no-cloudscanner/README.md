# Tenant Onboarding Without CloudScanner

This example demonstrates tenant onboarding without deploying CloudScanner infrastructure.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Disabled (no scanner infrastructure deployed)
- **Tags**: None
- **Key Vault**: Not created (only needed for CloudScanner)

## Configuration

This example uses:

- `azure_tenant_id` to scope monitoring to the entire tenant
- **Does NOT provide** `scanner_client_id` or `scanner_client_secret`
- CloudScanner infrastructure will not be deployed

## Use Case

Use this approach when you want to:

- Only use CloudAPI for discovery and monitoring (no active scanning)
- Reduce infrastructure footprint and costs
- Deploy CloudScanner separately or at a later time
- Use Upwind's agentless monitoring without the scanner component

## What Gets Deployed

Without CloudScanner credentials:

- ✅ Azure AD Application and Service Principal
- ✅ Role assignments for CloudAPI discovery
- ✅ Organizational credentials sent to Upwind
- ❌ Key Vault (not needed without CloudScanner)
- ❌ Container App Environment
- ❌ CloudScanner managed identity
- ❌ CloudScanner role assignments

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the Upwind credentials with your actual values
3. **Do NOT provide** scanner credentials
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
