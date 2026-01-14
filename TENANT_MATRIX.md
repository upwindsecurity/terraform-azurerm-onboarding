# Tenant Onboarding Matrix

These are the following options that we have for tenant onboarding.
Each option is demonstrated in a dedicated example.

## Scoping Options

* **Tenant level** - Monitor entire Azure tenant
  * Variable: `azure_tenant_id` included
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

* **Management group level** - Monitor specific management groups
  * Variables: `azure_management_group_ids` included, `azure_tenant_id` excluded
  * Example: [`examples/tenant-management-groups/`](examples/tenant-management-groups/)

* **Include subscriptions** - Monitor only specific subscriptions
  * Variables: `cloudapi_include_subscriptions`, `cloudscanner_include_subscriptions`
  * Example: [`examples/tenant-include-subscriptions/`](examples/tenant-include-subscriptions/)

* **Exclude subscriptions** - Monitor all except specific subscriptions
  * Variables: `cloudapi_exclude_subscriptions`, `cloudscanner_exclude_subscriptions`
  * Example: [`examples/tenant-exclude-subscriptions/`](examples/tenant-exclude-subscriptions/)

## CloudScanner Options

* **Deploy CloudScanner** - Full monitoring with active scanning
  * Variables: Include `scanner_client_id` and `scanner_client_secret`
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

* **Do not deploy CloudScanner** - Discovery only, no active scanning
  * Variables: Exclude scanner credentials (leave empty or omit)
  * Example: [`examples/tenant-no-cloudscanner/`](examples/tenant-no-cloudscanner/)

## Custom Tags

* **Include tags** - Apply custom tags to all resources
  * Variable: `tags = { ... }`
  * Example: [`examples/tenant-with-tags/`](examples/tenant-with-tags/)

* **No tags** - Use default (no custom tags)
  * Variable: `tags` not specified or `tags = {}`
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

## Key Vault Network Security

* **Deny traffic** - Restrict Key Vault access to specific IPs
  * Variables: `key_vault_deny_traffic = true`, `key_vault_ip_rules = ["public-ip"]`
  * **Required**: Must provide IP rules when deny traffic is enabled
  * Example: [`examples/tenant-keyvault-deny/`](examples/tenant-keyvault-deny/)

* **Allow traffic** - Default, allow all traffic
  * Variable: `key_vault_deny_traffic = false` (default)
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

## Quick Reference

| Example | Scoping | CloudScanner | Tags | Key Vault |
|---------|---------|--------------|------|-----------|
| [tenant-basic](examples/tenant-basic/) | Tenant | ✅ | ❌ | Allow |
| [tenant-management-groups](examples/tenant-management-groups/) | Mgmt Groups | ✅ | ❌ | Allow |
| [tenant-include-subscriptions](examples/tenant-include-subscriptions/) | Include Subs | ✅ | ❌ | Allow |
| [tenant-exclude-subscriptions](examples/tenant-exclude-subscriptions/) | Exclude Subs | ✅ | ❌ | Allow |
| [tenant-no-cloudscanner](examples/tenant-no-cloudscanner/) | Tenant | ❌ | ❌ | N/A |
| [tenant-with-tags](examples/tenant-with-tags/) | Tenant | ✅ | ✅ | Allow |
| [tenant-keyvault-deny](examples/tenant-keyvault-deny/) | Tenant | ✅ | ❌ | Deny |
| [tenant-advanced](examples/tenant-advanced/) | Exclude Subs | ✅ | ✅ | Deny |
