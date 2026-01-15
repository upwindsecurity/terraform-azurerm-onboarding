# Define local values to ensure consistency between provider and module configuration.
locals {
  # Replace these example values with your actual Azure IDs.
  azure_tenant_id                    = "12345678-1234-1234-1234-123456789012"
  azure_orchestrator_subscription_id = "87654321-4321-4321-4321-210987654321"
}

# Configure the Azure Resource Manager provider.
# The subscription_id should be set to your orchestrator subscription ID -
# this is the subscription where Upwind will deploy its infrastructure components.
# For detailed instructions on configuring the Azure provider, please refer to:
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
provider "azurerm" {
  subscription_id = local.azure_orchestrator_subscription_id
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

# Configure the Azure Active Directory provider.
provider "azuread" {
  tenant_id = local.azure_tenant_id
}

# Create an Azure AD application and service principal for Upwind tenant integration.
# This module sets up the necessary permissions and credentials for Upwind to monitor an entire Azure tenant.
module "upwind_integration_azure_onboarding" {
  count  = var.create ? 1 : 0 # Conditionally create resources based on the create variable.
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # Upwind organization configuration.
  # Replace these example values with your actual Upwind organization details.
  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  # Cloud Scanner credentials for deployment automation.
  # Replace these example values with your actual Cloud Scanner credentials.
  scanner_client_id     = "scanner_client_id_example"
  scanner_client_secret = "scanner_client_secret_example"

  # Azure tenant and subscription configuration.
  # These values are automatically consistent with the provider configuration above.
  azure_orchestrator_subscription_id = local.azure_orchestrator_subscription_id

  # Configure which Azure management groups to monitor.
  # Choose one of the following options (uncomment and modify as needed):

  # Option 1: Use the tenant root management group only (default behavior).
  azure_tenant_id = local.azure_tenant_id

  # Option 2: Use specific management group IDs.
  # azure_management_group_ids = [
  #   "custom-management-group-id"
  # ]

  # Additional option 1: Specify subscriptions to include.
  cloudapi_include_subscriptions = [
    "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
  ]

  cloudscanner_include_subscriptions = [
    "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
  ]

  # Additional option 2: Specify subscriptions to exclude.
  cloudapi_exclude_subscriptions = [
    "6703683f-8798-4a2d-8705-56738b445911",
  ]

  cloudscanner_exclude_subscriptions = [
    "6703683f-8798-4a2d-8705-56738b445911",
  ]


  # Optional configuration.
  resource_suffix             = "example"
  azure_cloudscanner_location = "westus"

  # Custom tags applied to all resources
  tags = {
    "environment" = "Production"
    "managed_by"  = "Terraform"
    "owner"       = "Security-Team"
    "cost_center" = "IT-Security"
    "project"     = "Upwind-Integration"
  }
}
