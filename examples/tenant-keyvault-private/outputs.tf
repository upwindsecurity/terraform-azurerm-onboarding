output "azure_application_client_id" {
  description = "The unique identifier for the Azure AD application (client)."
  value       = module.upwind_integration_azure_onboarding.azure_application_client_id
  sensitive   = true
}

output "azure_application_client_secret" {
  description = "The client secret for the Azure AD application."
  value       = module.upwind_integration_azure_onboarding.azure_application_client_secret
  sensitive   = true
}

output "azure_tenant_id" {
  description = "The unique identifier for the Azure tenant."
  value       = module.upwind_integration_azure_onboarding.azure_tenant_id
}

output "key_vault_name" {
  description = "The name of the private Key Vault. Add the scanner credentials from the Upwind console to this vault as secrets named 'upwind-client-id' and 'upwind-client-secret'."
  value       = module.upwind_integration_azure_onboarding.key_vault_name
}
