# Configure the Azure Resource Manager provider.
# For detailed instructions on configuring the Azure provider, please refer to:
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
provider "azurerm" {
  features {}
}

# Create an Azure AD application and service principal for Upwind integration.
# This module sets up the necessary permissions and credentials for Upwind to monitor Azure subscriptions.
module "upwind_cloud_credentials" {
  count  = var.create ? 1 : 0 # Conditionally create resources based on the create variable.
  source = "../../modules/subscription"

  # Upwind organization configuration.
  # Replace these example values with your actual Upwind organization details.
  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  # Configure which Azure subscriptions to include for monitoring.
  # Choose one of the following options (uncomment and modify as needed):

  # Option 1: Use the current subscription only (default behavior when azure_include_subscription_ids is empty).
  azure_include_subscription_ids = []

  # Option 2: Grant access to specific subscription IDs.
  # azure_include_subscription_ids = [
  #   "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
  # ]

  # Option 3: Grant access to all subscriptions within the tenant.
  # azure_include_all_subscriptions = true

  # Option 4: Grant access to all subscriptions except those explicitly excluded.
  # azure_exclude_subscription_ids = [
  #   "6703683f-8798-4a2d-8705-56738b445911",
  # ]

  # Option 5: Grant access to specified management groups instead of individual subscriptions.
  # azure_management_group_ids = [
  #   "863c7ca6-7ec9-43bf-ba6c-d9db91b5d556"
  # ]
}
