# Tenant Onboarding Matrix

These are the following options that we have for tenant onboarding.
Each option is demonstrated in a dedicated example.

## Scoping Options

* **Tenant level** - Monitor entire Azure tenant
  * Variable: `azure_tenant_id` included
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

* **Management group level** - Monitor specific management groups
  * Variables: `azure_management_group_ids` included, `azure_tenant_id` excluded (setting both is
    rejected at plan time - `azure_tenant_id` wins and would silently scope to the tenant root)
  * Scope stays inside the named hierarchy: role assignments land on those management groups, and
    exclude filters are expanded against the subscriptions under them (nested groups included) -
    the tenant-wide subscription list is never read (UP-4303)
  * With no subscription filter, the outpost path also assigns roles on the orchestrator
    subscription - it may sit outside the hierarchy and holds the CloudScanner resources. The SaaS
    path does not. Under a subscription filter neither path adds it
  * Examples: [`examples/tenant-management-groups/`](examples/tenant-management-groups/) (outpost),
    [`examples/tenant-saas-management-groups/`](examples/tenant-saas-management-groups/) (SaaS)

* **Include subscriptions** - Monitor only specific subscriptions
  * Variables: `cloudapi_include_subscriptions`, `cloudscanner_include_subscriptions`
  * The listed subscriptions are the whole scope - nothing is appended to them
  * Example: [`examples/tenant-include-subscriptions/`](examples/tenant-include-subscriptions/)

* **Exclude subscriptions** - Monitor all except specific subscriptions
  * Variables: `cloudapi_exclude_subscriptions`, `cloudscanner_exclude_subscriptions`
  * The set being excluded from is the current scope: all tenant subscriptions with `azure_tenant_id`
    set, or just the subscriptions under `azure_management_group_ids` when it is not
  * The resolved list is the whole scope, so an excluded subscription stays excluded - including the
    orchestrator subscription, which is no longer re-added on top of the filter (UP-4303 follow-up)
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

* **Private networking** - Fully disable public network access on the Key Vault
  * Variable: `key_vault_private_network = true`
  * **Note**: Terraform cannot write to a private vault, so you must add the
    `upwind-client-id` and `upwind-client-secret` secrets manually (scanner credentials are not passed to Terraform)
  * Mutually exclusive with `key_vault_deny_traffic`
  * Example: [`examples/tenant-keyvault-private/`](examples/tenant-keyvault-private/)

* **Allow traffic** - Default, allow all traffic
  * Variable: `key_vault_deny_traffic = false` (default)
  * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

* **Authentication** - How Upwind authenticates to the tenant (UP-3278)
  * Workload identity federation, secretless (default): `use_workload_identity_federation = true`
    * **Note**: WIF engages only when a fetcher identity is available (`fetcher_app_client_id` or
      `fetcher_app_service_principal_object_id` set, i.e. the org has azure-auth-service enabled). With
      no `fetcher_*` input the module auto-falls-back to the legacy client-secret flow, so orgs without
      azure auth service still onboard (UP-3947).
    * Example: [`examples/tenant-wif/`](examples/tenant-wif/)
  * Legacy client secret: `use_workload_identity_federation = false`
    * Example: [`examples/tenant-basic/`](examples/tenant-basic/)

## Quick Reference

| Example | Scoping | CloudScanner | Tags | Key Vault |
|---------|---------|--------------|------|-----------|
| [tenant-wif](examples/tenant-wif/) | Tenant | ✅ | ❌ | Allow |
| [tenant-basic](examples/tenant-basic/) | Tenant | ✅ | ❌ | Allow |
| [tenant-management-groups](examples/tenant-management-groups/) | Mgmt Groups | ✅ | ❌ | Allow |
| [tenant-saas-management-groups](examples/tenant-saas-management-groups/) | Mgmt Groups | N/A (SaaS) | ❌ | N/A |
| [tenant-include-subscriptions](examples/tenant-include-subscriptions/) | Include Subs | ✅ | ❌ | Allow |
| [tenant-exclude-subscriptions](examples/tenant-exclude-subscriptions/) | Exclude Subs | ✅ | ❌ | Allow |
| [tenant-no-cloudscanner](examples/tenant-no-cloudscanner/) | Tenant | ❌ | ❌ | N/A |
| [tenant-with-tags](examples/tenant-with-tags/) | Tenant | ✅ | ✅ | Allow |
| [tenant-keyvault-deny](examples/tenant-keyvault-deny/) | Tenant | ✅ | ❌ | Deny |
| [tenant-keyvault-private](examples/tenant-keyvault-private/) | Tenant | ✅ | ❌ | Private |
| [tenant-advanced](examples/tenant-advanced/) | Exclude Subs | ✅ | ✅ | Deny |
