locals {
  # Store subscription IDs directly assigned to management groups.
  management_group_subscription_ids = (
    length(var.azure_management_group_ids) > 0
    ? flatten([
      for mg in data.azurerm_management_group.all : mg.subscription_ids
    ])
    : []
  )

  # Store subscription IDs that are both 'Enabled' and not excluded.
  enabled_subscription_ids = [
    for s in data.azurerm_subscriptions.available.subscriptions :
    s.subscription_id if(
      lower(s.state) == "enabled" &&
      !contains(var.azure_exclude_subscription_ids, s.subscription_id)
    )
  ]

  # Determine the list of subscription IDs to process based on user input.
  subscription_ids = (
    # Check if management group IDs are provided.
    length(var.azure_management_group_ids) > 0
    # If management group IDs are provided, derive subscription IDs from these
    # groups. Filter these IDs to include only those that are also in the
    # enabled subscription IDs list.
    ? [
      for sid in local.management_group_subscription_ids :
      sid if contains(local.enabled_subscription_ids, sid)
    ]
    : (
      # Check if all subscriptions are to be included, or specific exclusions are defined.
      var.azure_include_all_subscriptions || length(var.azure_exclude_subscription_ids) > 0
      # Use the list of enabled subscription IDs, which already excludes those
      # specified in `azure_exclude_subscription_ids`.
      ? local.enabled_subscription_ids
      : (
        # If not including all subscriptions, use the explicitly provided list of subscription IDs.
        # If no subscription IDs are provided, default to the current subscription ID.
        coalescelist(
          var.azure_include_subscription_ids,
          [data.azurerm_subscription.current.subscription_id],
        )
      )
    )
  )

  # Identify subscription IDs with existing cloud credentials.
  connected_subscription_ids = {
    for cc in jsondecode(data.http.upwind_get_cloud_credentials_request.response_body) :
    cc.provider.subscription_id => true
    if(
      lower(cc.status) == "connected" &&
      lower(cc.provider.name) == "azure"
    )
  }

  # Identify subscription IDs without existing cloud credentials.
  unconnected_subscription_ids = [
    for sid in local.subscription_ids : sid
    if lookup(local.connected_subscription_ids, sid, false) == false
  ]

  # Define the scope for role assignments based on whether management group is
  # used. If `azure_use_management_group` is true, use the management group ID
  # as the scope. Otherwise, use the list of subscription IDs.
  role_assignment_scopes = coalescelist(
    var.azure_management_group_ids,
    local.subscription_ids
  )

  # Define the prefix for the scope URI based on whether the management group
  # is used. No prefix is needed for management group level; "/subscriptions/"
  # is used for subscriptions.
  role_assignment_scope_prefix = (
    length(var.azure_management_group_ids) > 0
    ? "/providers/Microsoft.Management/managementGroups/"
    : "/subscriptions/"
  )

  # Construct a map of role assignments using combinations of scopes and built-in roles.
  # This map is only created if there are valid scopes and roles to process.
  builtin_role_assignments = (
    length(local.role_assignment_scopes) > 0 &&
    length(var.azure_roles) > 0
    ? {
      for pair in setproduct(
        local.role_assignment_scopes,
        var.azure_roles,
      ) :
      "${local.role_assignment_scope_prefix}${pair[0]}|${pair[1]}" => {
        scope = "${local.role_assignment_scope_prefix}${pair[0]}"
        role  = pair[1]
      }
    }
    : {}
  )

  # Define the scopes for custom role assignments.
  custom_role_assignments = (
    length(var.azure_custom_role_permissions) > 0
    ? toset([
      for scope in local.role_assignment_scopes :
      "${local.role_assignment_scope_prefix}${scope}"
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
}

# Retrieve the current Azure AD client configuration.
data "azuread_client_config" "current" {}

# Retrieve the current Azure subscription details.
data "azurerm_subscription" "current" {}

# Retrieve a list of all available Azure subscriptions.
data "azurerm_subscriptions" "available" {}

# Retrieve a list of Azure management groups.
data "azurerm_management_group" "all" {
  for_each = toset(var.azure_management_group_ids)
  name     = each.value
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

  principal_id         = azuread_service_principal.this.id
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

  principal_id       = azuread_service_principal.this.id
  role_definition_id = azurerm_role_definition.custom[each.value].role_definition_resource_id
  scope              = each.value
}

# Delay further execution to allow built-in role assignments to propagate fully.
resource "time_sleep" "azurerm_builtin_role_assignment_wait" {
  for_each   = local.builtin_role_assignments
  depends_on = [azurerm_role_assignment.builtin]

  create_duration = var.azure_role_assignment_wait_time
}

# Delay further execution to allow custom role assignments to propagate fully.
resource "time_sleep" "azurerm_custom_role_assignment_wait" {
  for_each   = local.custom_role_assignments
  depends_on = [azurerm_role_assignment.custom]

  create_duration = var.azure_role_assignment_wait_time
}

# Retrieve existing cloud credentials.
data "http" "upwind_get_cloud_credentials_request" {
  method = "GET"

  url = format(
    "%s/v1/organizations/%s/cloud-credentials",
    var.upwind_region == "us" ? var.upwind_integration_endpoint : replace(var.upwind_integration_endpoint, ".upwind.", ".eu.upwind."),
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

    # The fix #35895 for issue #34310 is included in version 1.10.0 and later.
    # Since version 1.10.0 was recently released and is not yet widely adopted,
    # using postconditions could introduce or exacerbate errors. To prevent
    # potential issues, we should avoid using postconditions until this version
    # is more commonly utilized.
    #
    # postcondition {
    #   condition     = contains([200], self.status_code)
    #   error_message = "Error encountered with status code: ${self.status_code}. Response: ${self.response_body}."
    # }
  }
}

# Create cloud credentials for unconnected subscriptions.
# tflint-ignore: terraform_unused_declarations
data "http" "upwind_create_cloud_credentials_request" {
  for_each = toset(local.unconnected_subscription_ids)
  depends_on = [
    time_sleep.azurerm_builtin_role_assignment_wait,
    time_sleep.azurerm_custom_role_assignment_wait,
  ]

  method = "POST"

  url = format(
    "%s/v1/organizations/%s/cloud-credentials",
    var.upwind_region == "us" ? var.upwind_integration_endpoint : replace(var.upwind_integration_endpoint, ".upwind.", ".eu.upwind."),
    var.upwind_organization_id,
  )

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = format("Bearer %s", local.upwind_access_token)
  }

  request_body = jsonencode(
    {
      "provider" = {
        "name"            = "azure",
        "subscription_id" = each.value
      },
      "spec" = {
        "tenant_id"     = data.azuread_client_config.current.tenant_id
        "client_id"     = azuread_application.this.client_id,
        "client_secret" = azuread_application_password.client_secret.value,
      }
    }
  )

  retry {
    attempts = 3
  }

  lifecycle {
    precondition {
      condition     = local.upwind_access_token != null
      error_message = "Unable to obtain access token. Please verify your client ID and client secret. Response: ${data.http.upwind_get_access_token_request.response_body}."
    }

    # The fix #35895 for issue #34310 is included in version 1.10.0 and later.
    # Since version 1.10.0 was recently released and is not yet widely adopted,
    # using postconditions could introduce or exacerbate errors. To prevent
    # potential issues, we should avoid using postconditions until this version
    # is more commonly utilized.
    #
    # postcondition {
    #   condition     = contains([201, 204], self.status_code)
    #   error_message = "Error encountered with status code: ${self.status_code}. Response: ${self.response_body}."
    # }
  }
}
