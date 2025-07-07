output "upwind_next_step" {
  description = "The instructions for the next step in the process."
  value       = "Please proceed to the Upwind console at https://console.upwind.io to continue with the next steps of the process."
}

output "azure_tenant_id" {
  description = "The unique identifier for the current Azure tenant."
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_subscription_ids" {
  description = "The list of Azure subscription IDs that are included based on the current configuration."
  value       = local.subscription_ids
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
  value       = azuread_service_principal.this.id
}
