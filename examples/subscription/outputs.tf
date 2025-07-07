output "upwind_next_step" {
  description = "The instructions for the next step in the process."
  value       = one(module.upwind_cloud_credentials[*].upwind_next_step)
}

output "azure_tenant_id" {
  description = "The unique identifier for the current Azure tenant."
  value       = one(module.upwind_cloud_credentials[*].azure_tenant_id)
}

output "azure_subscription_ids" {
  description = "The list of Azure subscription IDs that are included based on the current configuration."
  value       = one(module.upwind_cloud_credentials[*].azure_subscription_ids)
}

output "azure_application_name" {
  description = "The display name for the Azure AD application."
  value       = one(module.upwind_cloud_credentials[*].azure_application_name)
}

output "azure_application_client_id" {
  description = "The unique identifier for the Azure AD application (client)."
  value       = one(module.upwind_cloud_credentials[*].azure_application_client_id)
}

output "azure_application_client_secret" {
  description = "The client secret for the Azure AD application."
  value       = one(module.upwind_cloud_credentials[*].azure_application_client_secret)
  sensitive   = true
}

output "azure_service_principal_id" {
  description = "The unique identifier for the Azure AD service principal."
  value       = one(module.upwind_cloud_credentials[*].azure_service_principal_id)
}
