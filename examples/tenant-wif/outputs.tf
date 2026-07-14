output "azure_tenant_id" {
  description = "The unique identifier for the Azure tenant."
  value       = module.upwind_integration_azure_onboarding.azure_tenant_id
}

output "azure_application_client_id" {
  description = "Client ID of the org's Upwind-minted WIF app registration."
  value       = module.upwind_integration_azure_onboarding.azure_application_client_id
  sensitive   = true
}

output "azure_service_principal_id" {
  description = "Object ID of the consented WIF service principal in this tenant."
  value       = module.upwind_integration_azure_onboarding.azure_service_principal_id
}
