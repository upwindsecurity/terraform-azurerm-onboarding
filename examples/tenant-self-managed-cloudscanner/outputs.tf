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

output "cloudscanner_key_vault_name" {
  description = "Name of the org-wide CloudScanner Key Vault. Pass this to the CloudScanner ARM template as the orgWideKeyVaultName parameter when running the template manually per region."
  value       = module.upwind_integration_azure_onboarding.cloudscanner_key_vault_name
}
