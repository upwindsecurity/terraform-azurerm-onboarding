output "upwind_next_step" {
  description = "The instructions for the next step in the process."
  value       = "Please proceed to the Upwind console at https://console.upwind.io to continue with the next steps of the process."
}

output "azure_tenant_id" {
  description = "The unique identifier for the current Azure tenant."
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_application_name" {
  description = "The display name for the Azure AD application."
  value       = local.app_name
}

output "azure_application_client_id" {
  description = "The unique identifier for the Azure AD application (client)."
  value       = azuread_application.this.client_id
}

output "azure_application_client_secret" {
  description = "The client secret for the Azure AD application."
  value       = azuread_application_password.client_secret.value
  sensitive   = true
}

output "azure_service_principal_id" {
  description = "The unique identifier for the Azure AD service principal."
  value       = azuread_service_principal.this.object_id
}

output "organizational_credentials" {
  value       = local.organizational_credentials
  description = "The Upwind organizational credentials that were created to onboard the Azure tenant."
}

output "pending_tenants" {
  value       = local.pending_tenants
  description = "The list of management groups that are pending onboarding."
}
