output "azure_tenant_id" {
  description = "The unique identifier for the Azure tenant."
  value       = module.upwind_integration_azure_onboarding.azure_tenant_id
}

output "saas_snapshot_service_principal_object_id" {
  description = "Object ID of the Snapshot service principal used for role assignments (echoes the supplied snapshot_app_service_principal_object_id)."
  value       = module.upwind_integration_azure_onboarding.saas_snapshot_service_principal_object_id
}

output "saas_fetcher_service_principal_object_id" {
  description = "Object ID of the Fetcher service principal used for role assignments (echoes the supplied fetcher_app_service_principal_object_id)."
  value       = module.upwind_integration_azure_onboarding.saas_fetcher_service_principal_object_id
}
