output "upwind_next_step" {
  description = "The instructions for the next step in the process."
  value       = "Please proceed to the Upwind console at https://console.upwind.io to continue with the next steps of the process."
}

output "azure_tenant_id" {
  description = "The unique identifier for the current Azure tenant."
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_application_name" {
  description = "The display name for the Azure AD application. Null in WIF mode (the app registration lives in Upwind's tenant, not this one)."
  value       = local.wif_enabled ? null : (local.create_new_application ? local.app_name : var.azure_application_client_id)
}

output "azure_application_client_id" {
  description = "The unique identifier for the Azure AD application (client). In WIF mode this is the org's Upwind-minted WIF app registration (null when only fetcher_app_service_principal_object_id was supplied)."
  value       = local.wif_enabled ? (var.fetcher_app_client_id != "" ? var.fetcher_app_client_id : null) : (local.create_new_application ? azuread_application.this[0].client_id : var.azure_application_client_id)
}

output "azure_application_client_secret" {
  description = "The client secret for the Azure AD application."
  value       = local.create_new_application ? azuread_application_password.client_secret[0].value : ""
  sensitive   = true
}

output "azure_service_principal_id" {
  description = "The unique identifier for the Azure AD service principal."
  value       = local.service_principal_object_id
}

output "organizational_credentials" {
  value       = local.organizational_credentials
  description = "The Upwind organizational credentials that were created to onboard the Azure tenant. Empty in SaaS and WIF modes (both secretless: no Upwind API call is made, so existing credentials are not queried)."
}

output "pending_tenant" {
  value       = local.pending_tenant
  description = "The tenant ID that is pending onboarding, or null if already onboarded. Always the tenant ID in SaaS and WIF modes (the onboarding-status lookup is skipped along with the other Upwind API calls)."
}

output "key_vault_name" {
  description = "The name of the CloudScanner Key Vault, or null if CloudScanner is not enabled. When key_vault_private_network is true, add the scanner credentials from the Upwind console to this vault as secrets named 'upwind-client-id' and 'upwind-client-secret' (names must be exact)."
  value       = local.cloudscanner_enabled ? azurerm_key_vault.orgwide_key_vault[0].name : null
}

output "key_vault_log_analytics_workspace_id" {
  value       = var.key_vault_logging_enabled && local.cloudscanner_enabled ? azurerm_log_analytics_workspace.kv_logging[0].id : null
  description = "The ID of the Log Analytics Workspace used for Key Vault diagnostic logging, or null if logging is not enabled."
}

output "saas_snapshot_service_principal_object_id" {
  description = "SaaS mode: object ID of the Snapshot app registration service principal - supplied via snapshot_app_service_principal_object_id, or created by the module (null when saas_enabled is false)."
  value       = var.saas_enabled ? local.saas_snapshot_sp_object_id : null
}

output "saas_fetcher_service_principal_object_id" {
  description = "SaaS mode: object ID of the Fetcher app registration service principal - supplied via fetcher_app_service_principal_object_id, or created by the module (null when saas_enabled is false)."
  value       = var.saas_enabled ? local.saas_fetcher_sp_object_id : null
}
