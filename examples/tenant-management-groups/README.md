# Management Group-Level Onboarding Example

This example demonstrates scoping monitoring to specific management groups instead of the entire tenant.

## Features

- **Scoping**: Management group level (monitors specific management groups)
- **CloudScanner**: Enabled
- **Tags**: None
- **Key Vault**: Default (allows traffic)

## Configuration

This example uses:

- `azure_management_group_ids` to scope to specific management groups
- **Does NOT use** `azure_tenant_id` (mutually exclusive with management groups)
- Scanner credentials to enable CloudScanner deployment

## Use Case

Use this approach when you want to:

- Monitor only specific parts of your Azure organization
- Exclude certain management groups from monitoring
- Have granular control over which subscriptions are monitored

## Scope Containment

Because `azure_tenant_id` is not set, nothing in this onboarding reaches outside the named
management groups:

- With no subscription filter (this example), role assignments are made on those management groups,
  plus the orchestrator subscription — it may sit outside the hierarchy and is where the outpost's
  own CloudScanner resources live
- If you add `cloudapi_exclude_subscriptions` / `cloudscanner_exclude_subscriptions`, the exclusion
  is expanded against the subscriptions **under those management groups** (nested groups included)
  — the tenant-wide subscription list is not read, so the runner needs no tenant-root visibility
- Under such a filter the resolved subscription list **is** the scope: the orchestrator subscription
  is no longer added on top, so it is covered only if it is in the hierarchy and you did not exclude
  it. Excluding it now actually excludes it (UP-4303 follow-up); previously it was silently re-added

The SaaS (provider-hosted) counterpart is
[tenant-saas-management-groups](../tenant-saas-management-groups/).

## Usage

1. Update the local values with your actual Azure IDs
2. Replace the management group IDs with your actual management group names
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
