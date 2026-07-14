# Tenant Onboarding With A Private Networking Key Vault

This example provisions the CloudScanner Key Vault with **public network access fully
disabled** (private networking). Because a private Key Vault is not reachable from the
public internet, Terraform cannot write secrets into it. Instead, **you** take on the
responsibility of adding the scanner credentials to the vault after the apply completes.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Private networking (`public_network_access_enabled = false`)

## Configuration

This example uses:

- `azure_tenant_id` to scope monitoring to the entire tenant
- `key_vault_private_network = true` to fully disable public network access on the Key Vault
- No scanner credentials are passed to Terraform - CloudScanner infrastructure is still
  provisioned, but the secrets are added to the Key Vault manually

## Use Case

Use this approach when your security policy requires that the CloudScanner Key Vault has no
public network exposure at all, and you are able to add secrets to the vault yourself through
a private path (e.g. from a peered network, a jump host, or a private endpoint).

## How It Differs From `tenant-keyvault-deny`

| | `tenant-keyvault-deny` | `tenant-keyvault-private` |
|---|---|---|
| Public network access | Enabled, restricted by IP allowlist | **Disabled** |
| Variable | `key_vault_deny_traffic` + `key_vault_ip_rules` | `key_vault_private_network` |
| Who writes the secrets | Terraform (from an allowed IP) | **You, manually** |
| `scanner_client_id` / `scanner_client_secret` | Required | Not used |

These two options are mutually exclusive - you cannot set both `key_vault_private_network`
and `key_vault_deny_traffic` at the same time.

## Important: You Must Add The Secrets Manually

Terraform creates the Key Vault and all CloudScanner infrastructure, but it does **not**
create the `upwind-client-id` and `upwind-client-secret` secrets, because it cannot reach a
private vault. After the apply, add them yourself.

1. Run the apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. Note the `key_vault_name` output:

   ```text
   Outputs:

   key_vault_name = "kv-<hash><suffix>"
   ```

3. Find that Key Vault in the Azure portal (or via a private path you control) and add two
   secrets with these **exact** names:

   - `upwind-client-id` - the `AzureScannersReportingCredentials` **client id** value from
     the Upwind console.
   - `upwind-client-secret` - the `AzureScannersReportingCredentials` **client secret** value
     from the Upwind console.

   CloudScanner will not be able to authenticate until both secrets are present.

## Clean Up

```bash
terraform destroy
```
