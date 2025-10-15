locals {
  # If tenant ID is supplied, use it as the management group
  # Otherwise use the provided management group IDs for backwards compatibility
  management_group_ids = var.azure_tenant_id != "" ? [var.azure_tenant_id] : var.azure_management_group_ids

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

  # Determine effective scopes for service principal role assignments
  # Use cloudapi include/exclude subscription logic or fall back to organizational scope
  base_effective_scopes = length(var.cloudapi_include_subscriptions) > 0 ? [
    for sub_id in var.cloudapi_include_subscriptions :
    "/subscriptions/${sub_id}"
    ] : (
    length(var.cloudapi_exclude_subscriptions) > 0 ? [
      for sub in data.azurerm_subscriptions.all.subscriptions :
      "/subscriptions/${sub.subscription_id}"
      if !contains(var.cloudapi_exclude_subscriptions, sub.subscription_id)
    ] : local.normalized_management_group_ids
  )

  orchestrator_subscription_scope = "/subscriptions/${var.azure_orchestrator_subscription_id}"
  using_sub_management_group      = var.azure_tenant_id == "" && length(var.azure_management_group_ids) > 0

  # Determine final effective scopes with orchestrator subscription handling:
  #
  # Scenario 1: Root tenant management group (azure_tenant_id is set)
  #   - Use the tenant root scope only
  #   - Don't add orchestrator subscription separately (already covered by tenant root)
  #
  # Scenario 2: Sub-management group (azure_management_group_ids is set, azure_tenant_id is empty)
  #   - Use the sub-management group scope
  #   - Add orchestrator subscription explicitly (may not be in the sub-management group hierarchy)
  #
  # Scenario 3: Explicit include/exclude subscription lists
  #   - Use the computed subscription list
  #   - Add orchestrator subscription only if not already in the list
  effective_scopes = (
    length(var.cloudapi_include_subscriptions) == 0 &&
    length(var.cloudapi_exclude_subscriptions) == 0 &&
    local.using_sub_management_group
    ) ? concat(local.base_effective_scopes, [local.orchestrator_subscription_scope]) : (
    # For include/exclude lists, only add orchestrator if not already present
    length(var.cloudapi_include_subscriptions) > 0 || length(var.cloudapi_exclude_subscriptions) > 0 ?
    (!contains(local.base_effective_scopes, local.orchestrator_subscription_scope) ?
      concat(local.base_effective_scopes, [local.orchestrator_subscription_scope]) :
      local.base_effective_scopes
    ) : local.base_effective_scopes
  )

  # Construct a map of role assignments using combinations of scopes and built-in roles.
  # This map is only created if there are valid scopes and roles to process.
  builtin_role_assignments = (
    length(local.effective_scopes) > 0 &&
    length(var.azure_roles) > 0
    ? {
      for pair in setproduct(
        local.effective_scopes,
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
      for scope in local.effective_scopes :
      scope
    ])
    : []
  )

  # Generate a unique application name (only used when creating new app).
  app_name = format(
    "%s-%s",
    var.azure_application_name_prefix,
    random_id.uid.hex,
  )

  # Determine if we should create a new app or use existing
  create_new_application = var.azure_application_client_id == null

  # Generate a unique custom role name prefix.
  custom_role_name_prefix = format(
    "%s-%s",
    var.azure_custom_role_name_prefix,
    random_id.uid.hex,
  )

  # Only create credentials if there are pending tenants and we're not in destroy mode
  create_credentials = length(local.pending_tenants) > 0 && var.create_organizational_credentials

  # Get the service principal object ID (from either new or existing)
  service_principal_object_id = local.create_new_application ? azuread_service_principal.this[0].object_id : data.azuread_service_principal.existing[0].object_id

  # Get the application client ID (from either new or existing)
  application_client_id = local.create_new_application ? azuread_application.this[0].client_id : var.azure_application_client_id

  # For existing applications, assume the app owner has configured permissions
  needs_api_access = local.create_new_application && length(var.azure_application_msgraph_roles) > 0
}

# Retrieve the current Azure AD client configuration.
data "azuread_client_config" "current" {}

# Get all subscriptions for exclude logic
data "azurerm_subscriptions" "all" {}

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

# Data source for existing application (when provided)
data "azuread_application" "existing" {
  count     = local.create_new_application ? 0 : 1
  client_id = var.azure_application_client_id
}

# Create an Azure AD application with the required permissions (only when not using existing).
resource "azuread_application" "this" {
  count        = local.create_new_application ? 1 : 0
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
  count = local.needs_api_access ? 1 : 0

  application_id = azuread_application.this[0].id
  api_client_id  = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

  role_ids = [
    for role in var.azure_application_msgraph_roles :
    data.azuread_service_principal.msgraph.app_role_ids[role]
  ]
}

# Data source for existing service principal (when using existing app)
data "azuread_service_principal" "existing" {
  count     = local.create_new_application ? 0 : 1
  client_id = var.azure_application_client_id
}

# Create a service principal for the Azure AD application (only for new applications).
resource "azuread_service_principal" "this" {
  count     = local.create_new_application ? 1 : 0
  client_id = azuread_application.this[0].client_id
  owners = coalescelist(
    var.azure_application_owners,
    [data.azuread_client_config.current.object_id]
  )
}

# Create a long-lived password for the Azure AD application (only for new applications).
resource "azuread_application_password" "client_secret" {
  count      = local.create_new_application ? 1 : 0
  depends_on = [azuread_service_principal.this]

  application_id = azuread_application.this[0].id
  end_date       = "2999-12-31T23:59:59Z"
}

# Assign built-in roles to the service principal.
resource "azurerm_role_assignment" "builtin" {
  for_each = local.builtin_role_assignments

  principal_id         = local.service_principal_object_id
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

  principal_id       = local.service_principal_object_id
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
          "tenant_id"     = local.create_new_application ? azuread_service_principal.this[0].application_tenant_id : data.azuread_service_principal.existing[0].application_tenant_id
          "client_id"     = local.application_client_id
          "client_secret" = local.create_new_application ? azuread_application_password.client_secret[0].value : var.azure_application_client_secret
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
