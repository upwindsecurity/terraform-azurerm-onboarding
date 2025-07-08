data "azurerm_management_group" "root_tenant_as_management_group" {
  count = var.azure_tenant_id != "" ? 1 : 0
  name  = var.azure_tenant_id
}

locals {
  # If tenant ID is supplied and apply_to_child_groups is true, get its direct child management groups
  # If tenant ID is supplied but apply_to_child_groups is false, use the tenant ID as the management group
  # Otherwise use the provided management group IDs for backwards compatibility
  management_group_ids = var.azure_tenant_id != "" ? (
    var.apply_to_child_groups ? [
      for mg in try(data.azurerm_management_group.root_tenant_as_management_group[0].management_group_ids, []) : mg
    ] : [var.azure_tenant_id]
  ) : var.azure_management_group_ids

  # Normalize management group IDs to handle both formats (name only or full resource ID)
  normalized_management_group_ids = [
    for mg_id in local.management_group_ids :
    startswith(mg_id, "/providers/Microsoft.Management/managementGroups/") ?
    mg_id : "/providers/Microsoft.Management/managementGroups/${mg_id}"
  ]

  # Create a map of existing organizational credentials
  organizational_credentials = {
    for cc in jsondecode(data.http.upwind_get_organizational_credentials_request.response_body) :
    lower(cc.azureOrganizationId) => true
  }

  # Tenant IDs to onboard - kept as an array for future compatibility to multiple tenants
  tenant_ids = var.azure_tenant_id != "" ? [var.azure_tenant_id] : [local.management_group_ids[0]]

  # Gather tenant IDs pending onboarding, i.e. those that do not have existing credentials
  pending_tenants = [
    for tenant_id in local.tenant_ids : tenant_id
    if lookup(local.organizational_credentials, tenant_id, false) == false
  ]

  # Construct a map of role assignments using combinations of scopes and built-in roles.
  # This map is only created if there are valid scopes and roles to process.
  builtin_role_assignments = (
    length(local.normalized_management_group_ids) > 0 &&
    length(var.azure_roles) > 0
    ? {
      for pair in setproduct(
        local.normalized_management_group_ids,
        var.azure_roles,
      ) :
      "${pair[0]}|${pair[1]}" => {
        scope = pair[0]
        role  = pair[1]
      }
    }
    : {}
  )

  # Define the scopes for custom role assignments.
  custom_role_assignments = (
    length(var.azure_custom_role_permissions) > 0
    ? toset([
      for scope in local.normalized_management_group_ids :
      scope
    ])
    : []
  )

  # Generate a unique application name.
  app_name = format(
    "%s-%s",
    var.azure_application_name_prefix,
    random_id.uid.hex,
  )

  # Generate a unique custom role name prefix.
  custom_role_name_prefix = format(
    "%s-%s",
    var.azure_custom_role_name_prefix,
    random_id.uid.hex,
  )

  # Only create credentials if there are pending tenants and we're not in destroy mode
  create_credentials = length(local.pending_tenants) > 0 && var.create_organizational_credentials
}

# Retrieve the current Azure AD client configuration.
data "azuread_client_config" "current" {}

# Retrieve the orchestrator Azure subscription details.
data "azurerm_subscription" "orchestrator" {
  subscription_id = var.azure_orchestrator_subscription_id
}

# Retrieve application IDs for APIs published by Microsoft.
data "azuread_application_published_app_ids" "well_known" {}

# Retrieve the Microsoft Graph service principal details.
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

# Generate a random ID to ensure unique naming for Azure resources.
resource "random_id" "uid" {
  byte_length = 4
}

# Generate a random ID to ensure unique naming for Azure custom roles.
resource "random_id" "rid" {
  for_each = local.custom_role_assignments

  byte_length = 4
}

# Create an Azure AD application with the required permissions.
resource "azuread_application" "this" {
  display_name = local.app_name
  owners = coalescelist(
    var.azure_application_owners,
    [data.azuread_client_config.current.object_id]
  )
  marketing_url = "https://www.upwind.io/"
  web {
    homepage_url = "https://www.upwind.io/"
  }

  lifecycle {
    ignore_changes = [
      # This block is analogous to the `azuread_application_api_access` resource.
      required_resource_access,
    ]
  }
}

# Grant Microsoft Graph API roles to the Azure AD application.
resource "azuread_application_api_access" "msgraph" {
  count = length(var.azure_application_msgraph_roles) > 0 ? 1 : 0

  application_id = azuread_application.this.id
  api_client_id  = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

  role_ids = [
    for role in var.azure_application_msgraph_roles :
    data.azuread_service_principal.msgraph.app_role_ids[role]
  ]
}

# Create a service principal for the Azure AD application.
resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
  owners = coalescelist(
    var.azure_application_owners,
    [data.azuread_client_config.current.object_id]
  )
}

# Create a long-lived password for the Azure AD application.
resource "azuread_application_password" "client_secret" {
  depends_on = [azuread_service_principal.this]

  application_id = azuread_application.this.id
  end_date       = "2999-12-31T23:59:59Z"
}

# Assign built-in roles to the service principal.
resource "azurerm_role_assignment" "builtin" {
  for_each = local.builtin_role_assignments

  principal_id         = azuread_service_principal.this.object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# Define custom role definition.
resource "azurerm_role_definition" "custom" {
  for_each = local.custom_role_assignments

  # Use a unique ID for each custom role definition to prevent conflicts
  # and ensure distinct identification of each role within the Azure
  # directory. Format the ID as [prefix]-[uid]-[rid].
  name = format(
    "%s-%s",
    local.custom_role_name_prefix,
    random_id.rid[each.key].hex,
  )
  scope = each.value

  permissions {
    actions     = var.azure_custom_role_permissions
    not_actions = []
  }
}

# Assign the custom role to the service principal.
resource "azurerm_role_assignment" "custom" {
  for_each = local.custom_role_assignments

  principal_id       = azuread_service_principal.this.object_id
  role_definition_id = azurerm_role_definition.custom[each.value].role_definition_resource_id
  scope              = each.value
}

data "http" "upwind_get_organizational_credentials_request" {
  method = "GET"

  url = format(
    "%s/v1/organizations/%s/organizational-credentials/azure",
    local.upwind_integration_endpoint,
    var.upwind_organization_id,
  )

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = format("Bearer %s", local.upwind_access_token)
  }

  retry {
    attempts = 3
  }

  lifecycle {
    precondition {
      condition     = local.upwind_access_token != null
      error_message = "Unable to obtain access token. Please verify your client ID and client secret. Response: ${data.http.upwind_get_access_token_request.response_body}."
    }
  }
}

# Wait for the builtin role assignments to be created
resource "time_sleep" "builtin_role_assignment_wait" {
  depends_on      = [azurerm_role_assignment.builtin]
  create_duration = var.azure_role_definition_wait_time
}

# Post the cloud credentials for organizational onboarding for management groups pending onboarding.
# tflint-ignore: terraform_unused_declarations
data "http" "upwind_create_organizational_credentials_request" {
  for_each = local.create_credentials ? toset(local.pending_tenants) : []

  # the built in role assignments need to be created before the cloud credentials can be created
  # the integration API validates Reader access on the management group
  depends_on = [time_sleep.builtin_role_assignment_wait]

  method = "POST"
  url = format(
    "%s/v1/organizations/%s/organizational-accounts/azure/onboard",
    local.upwind_integration_endpoint,
    var.upwind_organization_id,
  )

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = format("Bearer %s", local.upwind_access_token)
  }

  request_body = jsonencode(
    {
      "azure_organization_id" = each.value
      "create_credentials_request" = {
        "provider" = {
          "name"            = "azure",
          "subscription_id" = var.azure_orchestrator_subscription_id
        },
        "spec" = {
          "tenant_id"     = azuread_service_principal.this.application_tenant_id
          "client_id"     = azuread_service_principal.this.client_id
          "client_secret" = azuread_application_password.client_secret.value
        }
      }
    }
  )

  lifecycle {
    precondition {
      condition     = local.upwind_access_token != null
      error_message = "Unable to obtain access token. Please verify your client ID and client secret. Response: ${data.http.upwind_get_access_token_request.response_body}."
    }
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 201 || self.status_code == 409
      error_message = "Error encountered with status code: ${self.status_code}. Response: ${self.response_body}."
    }
  }
}

# endregion
