# Workload Identity Federation (WIF) Tenant Onboarding

Secretless self-hosted onboarding. Instead of creating an app registration and
client secret in your tenant, the module materializes the consented service
principal of your organization's Upwind-minted WIF app registration and grants
it the standard self-hosted role set. Upwind authenticates as that app via
workload identity federation - no client secret exists or is transferred.

Compared to the legacy flow (`use_workload_identity_federation = false`):

- No `azuread_application`, `azuread_application_password`, or Microsoft Graph
  API grants are created in your tenant.
- No `upwind_client_id` / `upwind_client_secret` are required and no Upwind API
  calls are made from Terraform.
- All other self-hosted resources (Key Vault, managed identities, scanner
  roles, CloudScanner infrastructure) are created as usual.

`wif_app_client_id` is shown in the Upwind console after adding the Azure
organization. If the Terraform runner lacks Microsoft Graph permissions to
create service principals, pre-consent the app registration (e.g. via
`az ad sp create --id <wif_app_client_id>`) and supply
`wif_app_service_principal_object_id` instead.

Requires the organization to be WIF-enabled on the Upwind side
(`azure-auth-service-enabled`).
