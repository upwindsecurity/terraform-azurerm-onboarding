# Configure the Azure Resource Manager provider.
# For detailed instructions on configuring the Azure provider, please refer to:
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
provider "azurerm" {
  subscription_id = "12345678-1234-1234-1234-123456789012"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      recover_soft_deleted_keys = true
    }
  }
}

# Configure the Azure Active Directory provider.
provider "azuread" {
  tenant_id = "87654321-4321-4321-4321-210987654321"
}

# Create an Azure AD application and service principal for Upwind tenant integration.
# This module sets up the necessary permissions and credentials for Upwind to monitor an entire Azure tenant.
module "upwind_integration_azure_onboarding" {
  count  = var.create ? 1 : 0 # Conditionally create resources based on the create variable.
  source = "../../modules/tenant"

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
  # Replace these example values with your actual Azure tenant and subscription IDs.
  azure_orchestrator_subscription_id = "12345678-1234-1234-1234-123456789012"

  # Configure which Azure management groups to monitor.
  # Choose one of the following options (uncomment and modify as needed):

  # Option 1: Use the tenant root management group only (default behavior).
  azure_tenant_id       = "87654321-4321-4321-4321-210987654321"
  apply_to_child_groups = false

  # Option 2: Use all child management groups within the tenant.
  # azure_tenant_id        = "87654321-4321-4321-4321-210987654321"
  # apply_to_child_groups   = true

  # Option 3: Use specific management group IDs.
  # azure_management_group_ids = [
  #   "custom-management-group-id"
  # ]

  # Optional configuration.
  resource_suffix             = "example"
  azure_cloudscanner_location = "westus"
}
