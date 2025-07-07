provider "azurerm" {
  # For detailed instructions on configuring the Azure provider, please refer to:
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
  features {}
}

module "upwind_cloud_credentials" {
  source = "../../modules/subscription"

  upwind_organization_id = "org_example12345"
  upwind_client_id       = "upwind_client_id_example"
  upwind_client_secret   = "upwind_client_secret_example"

  azure_include_subscription_ids = [
    "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
  ]

  # Grants access to all subscriptions within the tenant.
  # azure_include_all_subscriptions = true

  # Grants access only to specified subscriptions.
  # azure_include_subscription_ids = [
  #   "a9c07ec5-380c-4ca0-8767-09d16acfd87a",
  # ]

  # Grants access to all subscriptions except those explicitly excluded.
  # azure_exclude_subscription_ids = [
  #   "6703683f-8798-4a2d-8705-56738b445911",
  # ]

  # Grants access to specified management groups.
  # azure_management_group_ids = [
  #   "863c7ca6-7ec9-43bf-ba6c-d9db91b5d556"
  # ]
}
