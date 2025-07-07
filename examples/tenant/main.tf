module "upwind_integration_azure_onboarding" {
  source = "../../modules/tenant"

  # Required Upwind configuration
  upwind_organization_id             = "org_example12345"   # Upwind Organization ID
  upwind_client_id                   = "upwind_client_id_example"   # Upwind client credentials ID
  upwind_client_secret               = "upwind_client_secret_example"   # Upwind client credentials secret
  
  # Cloud Scanner Credentials
  scanner_client_id                  = "scanner_client_id_example"   # Cloud Scanner credentials ID
  scanner_client_secret              = "scanner_client_secret_example"   # Cloud Scanner credentials secret
  
  # Azure Organization Info
  azure_tenant_id                    = "fd4c2325-d478-4d58-809f-a8b2f9bb07ab"   # Azure tenant ID

  # Subscription to act as the orchestrator
  azure_orchestrator_subscription_id    = "a8c59695-475e-43d5-bf79-36e870f628db"   # Azure subscription ID for orchestrator

  # Resource suffix
  resource_suffix                    = "funefgi"

  # Where we will deploy the org-wide resource group, this will not have any effect on cloud scanners deployed to different regions.
  azure_cloudscanner_location = "westus"
}