# Tenant Onboarding With Key Vault Network Restrictions

This example demonstrates securing the Key Vault with network ACLs to restrict access.

## Features

- **Scoping**: Tenant level (monitors entire Azure tenant)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Deny traffic with IP allowlist

## Configuration

This example uses:

- `azure_tenant_id` to scope monitoring to the entire tenant
- `key_vault_deny_traffic = true` to enable network ACLs
- `key_vault_ip_rules` to specify allowed IP addresses/CIDR blocks
- Scanner credentials to enable CloudScanner deployment

## Use Case

Use this approach when you want to:

- Enhance security by restricting Key Vault access
- Comply with security policies requiring network restrictions
- Limit Key Vault access to specific IP addresses or ranges
- Follow zero-trust security principles

## Important Notes

### Required Configuration

When `key_vault_deny_traffic = true`, you **MUST** provide `key_vault_ip_rules` with at least one IP address or CIDR block.
Otherwise, Terraform will be unable to access the Key Vault to store secrets.

### What Gets Allowed

- ✅ IP addresses/CIDR blocks specified in `key_vault_ip_rules`
- ✅ Azure trusted services (automatically allowed)
- ✅ CloudScanner via service endpoints (subnet access)
- ❌ All other public internet access

### Finding Your IP Address

You can find your public IP address at:

- <https://whatismyipaddress.com/>
- Or run: `curl ifconfig.me`

### IP Format Examples

```hcl
key_vault_ip_rules = [
  "203.0.113.42",           # Single IP address
  "198.51.100.0/24",        # CIDR block
  "192.0.2.0/24",           # Another CIDR block
]
```

## Security Considerations

- Keep your IP allowlist minimal and up-to-date
- Use CIDR blocks for office networks or VPN ranges
- Remove IP addresses that are no longer needed
- Consider using Azure Private Endpoints for enhanced security
- Monitor Key Vault access logs for unauthorized attempts

## Usage

1. Update the local values with your actual Azure IDs
2. **Important**: Set `my_public_ip` to your actual public IP address
3. Add any additional IP addresses or CIDR blocks to `key_vault_ip_rules`
4. Replace the Upwind credentials with your actual values
5. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Troubleshooting

If you get "Access denied" errors:

1. Verify your IP address is correct
2. Check if your IP has changed (dynamic IPs)
3. Ensure the IP is in the correct format
4. Wait a few minutes for ACL changes to propagate

## Clean Up

```bash
terraform destroy
```
