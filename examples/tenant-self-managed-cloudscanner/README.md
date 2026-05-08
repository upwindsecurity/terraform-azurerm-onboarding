# Self-Managed CloudScanner Tenant Onboarding Example

This example demonstrates onboarding a tenant whose security policy prohibits
vendor-managed deployments. Upwind does not get the CloudScanner deployer role,
and the customer is responsible for running the CloudScanner ARM template
themselves once Terraform has finished provisioning the supporting
infrastructure.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled, but Upwind does **not** get the deployer role
- **Self-managed mode**: `self_managed_cloudscanner = true`
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## What this provisions

This example creates everything `tenant-basic` creates, **except** the
CloudScanner deployer role and its assignment to Upwind's service principal.
That includes:

- The org-wide resource group (tagged `UpwindManagedCloudScanners = "Disabled"`)
- The CloudScanner Key Vault
- All worker / scaler / target / storage-reader / Key Vault crypto roles and
  managed identities
- All CSPM-side reader roles and the Azure AD application

The `UpwindManagedCloudScanners = "Disabled"` tag is read by `onboarding-service`
at admin-account discovery time and short-circuits the auto-deploy paths, so
Upwind will not attempt to deploy CloudScanner on the customer's behalf.

## What the customer must do separately

Once Terraform has applied successfully, the customer runs the CloudScanner
ARM template manually, **once per region** they want CloudScanner deployed:

```bash
az deployment sub create \
  --location <region> \
  --template-uri https://get.upwind.io/armtemplates/azure-cloudscanner/main-70.json \
  --parameters \
      region=<region> \
      orgId=<upwind-org-id> \
      scannerId=<upwind-scanner-id> \
      orgWideKeyVaultName=<cloudscanner_key_vault_name output> \
      upwindRegion=us
```

The `orgWideKeyVaultName` value comes from the `cloudscanner_key_vault_name`
output of this example.

For full guidance (VM SKU selection, BYO networking, parameter reference,
upgrades), see the **Customer Self-Managed Cloudscanner Deployment (Azure)**
runbook in the Engineering Confluence space.

## Usage

1. Update the local values with your actual Azure IDs.
1. Replace the Upwind credentials with your actual values.
1. Run `terraform init`, then `terraform plan`, then `terraform apply`:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

1. Hand the `cloudscanner_key_vault_name` output to the customer along with
   the runbook above.

## Clean Up

```bash
terraform destroy
```
