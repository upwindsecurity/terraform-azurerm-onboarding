output "upwind_next_step" {
  description = "The instructions for the next step in the process."
  value       = one(module.upwind_integration_azure_onboarding[*].upwind_next_step)
}

output "azure_tenant_id" {
  description = "The unique identifier for the current Azure tenant."
  value       = one(module.upwind_integration_azure_onboarding[*].azure_tenant_id)
}

output "azure_application_name" {
  description = "The display name for the Azure AD application."
  value       = one(module.upwind_integration_azure_onboarding[*].azure_application_name)
}

output "azure_application_client_id" {
  description = "The unique identifier for the Azure AD application (client)."
  value       = one(module.upwind_integration_azure_onboarding[*].azure_application_client_id)
}

output "azure_application_client_secret" {
  description = "The client secret for the Azure AD application."
  value       = one(module.upwind_integration_azure_onboarding[*].azure_application_client_secret)
  sensitive   = true
}

output "azure_service_principal_id" {
  description = "The unique identifier for the Azure AD service principal."
  value       = one(module.upwind_integration_azure_onboarding[*].azure_service_principal_id)
}

output "organizational_credentials" {
  description = "The Upwind organizational credentials that were created to onboard the Azure tenant."
  value       = one(module.upwind_integration_azure_onboarding[*].organizational_credentials)
}

output "pending_tenants" {
  description = "The list of management groups that are pending onboarding."
  value       = one(module.upwind_integration_azure_onboarding[*].pending_tenants)
}
