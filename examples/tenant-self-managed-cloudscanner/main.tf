# Self-Managed CloudScanner Tenant Onboarding Example
# This example demonstrates onboarding a tenant whose security policy prohibits
# vendor-managed deployments. Upwind does not get the CloudScanner deployer role
# and the customer is responsible for running the CloudScanner ARM template
# themselves. See the "Customer Self-Managed Cloudscanner Deployment (Azure)"
# runbook in Confluence for the manual deployment procedure.

locals {
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

provider "azurerm" {
  subscription_id                = local.azure_orchestrator_subscription_id
  resource_providers_to_register = ["Microsoft.App"]
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      recover_soft_deleted_keys       = true
      recover_soft_deleted_secrets    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
  tenant_id = local.azure_tenant_id
}

module "upwind_integration_azure_onboarding" {
  # Local relative path so the example validates in-repo before the next
  # release. Customers consuming this as a template should swap to:
  #   source  = "upwindsecurity/onboarding/azurerm//modules/tenant"
  #   version = "~> X.Y"
  source = "../../modules/tenant"

  # Upwind organization configuration
  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  # Cloud Scanner credentials
  scanner_client_id     = "scanner_client_id_example"
  scanner_client_secret = "scanner_client_secret_example"

  # Azure configuration - Tenant level scope
  azure_tenant_id                    = local.azure_tenant_id
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id
  azure_cloudscanner_location        = "westus"

  resource_suffix = "example"

  # Self-managed CloudScanner: skip the deployer role assignment to Upwind's SP
  # and tag the org-wide RG so onboarding-service stays out of the way. The
  # customer must deploy the CloudScanner ARM template themselves per region.
  self_managed_cloudscanner = true
}
