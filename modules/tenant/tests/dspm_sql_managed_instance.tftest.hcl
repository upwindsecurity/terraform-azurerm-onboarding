# Azure SQL MI DSPM, orchestrator side: the executor gets the Scan Instance
# Operator role on the scan instance RG only (including instance delete, used by
# offboarding), never the private endpoint auto-approval action (it approves its
# endpoint manually instead). The executor builds the scan instance network
# itself and offboarding removes it, so Scan Network can write and delete it,
# in the scan RG only.

mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_data "azuread_application_published_app_ids" {
    defaults = {
      result = { MicrosoftGraph = "00000003-0000-0000-c000-000000000000" }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "null" {}
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"access_token\":\"test-token\"}"
    }
  }
}

override_data {
  target = data.http.upwind_get_organizational_credentials_request
  values = {
    status_code   = 200
    response_body = "[]"
  }
}

# Outpost with CloudScanner enabled; each run turns the feature on or off.
variables {
  upwind_organization_id             = "org_test"
  upwind_client_id                   = "client"
  upwind_client_secret               = "secret"
  scanner_client_id                  = "scanner"
  scanner_client_secret              = "scanner-secret"
  azure_orchestrator_subscription_id = "00000000-0000-0000-0000-000000000000"
  azure_tenant_id                    = "00000000-0000-0000-0000-000000000002"
  azure_application_msgraph_roles    = []
}

run "disabled_by_default_creates_nothing" {
  command = plan

  assert {
    condition = (
      length(azurerm_resource_group.dspm_sql_managed_instance) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0
    )
    error_message = "nothing for Azure SQL MI DSPM may be created while upwind_feature_dspm_azure_sql_managed_instance_enabled is false"
  }
}

# The executor runs in Upwind's cluster, so in Outpost it signs in as the
# onboarding service principal: an existing app here, to pin its object ID.
run "outpost_roles_go_to_onboarding_service_principal" {
  command = plan
  variables {
    azure_application_client_id                            = "00000000-0000-0000-0000-0000000000c1"
    azure_application_client_secret                        = "existing-app-secret-value"
    azure_application_service_principal_object_id          = "00000000-0000-0000-0000-0000000000c2"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = alltrue([
      azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator[0].principal_id == "00000000-0000-0000-0000-0000000000c2",
      azurerm_role_assignment.dspm_sql_managed_instance_scan_network[0].principal_id == "00000000-0000-0000-0000-0000000000c2",
      azurerm_role_assignment.dspm_sql_managed_instance_network_join[0].principal_id == "00000000-0000-0000-0000-0000000000c2",
    ])
    error_message = "Outpost assigns the DSPM roles to the onboarding service principal"
  }
  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_network_join[0].scope == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "the Outpost join role is assigned on the orchestrator subscription (the worker VNet is created later in the scanner's RG)"
  }
}

# WIF (the default for WIF-capable orgs): the onboarding principal is the Fetcher
# app's service principal, which Upwind signs in as through azure-auth-service.
run "outpost_wif_roles_go_to_fetcher_service_principal" {
  command = plan
  variables {
    fetcher_app_service_principal_object_id                = "00000000-0000-0000-0000-0000000000f1"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator[0].principal_id == "00000000-0000-0000-0000-0000000000f1"
    error_message = "in WIF mode the DSPM roles go to the Fetcher app's service principal"
  }
}

run "scan_instance_operator_has_scan_cycle_actions" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = alltrue([
      for a in [
        "Microsoft.Sql/managedInstances/crossSubscriptionPITR/action",
        "Microsoft.Sql/managedInstances/privateEndpointConnections/write",
        "Microsoft.Sql/managedInstances/keys/write",
        "Microsoft.Sql/locations/*/read",
      ] : contains(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].permissions[0].actions, a)
    ])
    error_message = "Scan Instance Operator is missing an action the scan cycle needs"
  }
  assert {
    condition     = contains(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].permissions[0].actions, "Microsoft.Sql/managedInstances/delete")
    error_message = "Scan Instance Operator must let offboarding discard the scan instance"
  }
  assert {
    condition = length(setintersection(
      toset(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].permissions[0].actions),
      toset([
        "Microsoft.Sql/managedInstances/*/action",
        "Microsoft.Sql/managedInstances/privateEndpointConnectionsApproval/action",
        "Microsoft.Sql/privateEndpointConnectionsApproval/action",
      ])
    )) == 0
    error_message = "Scan Instance Operator must not grant private endpoint auto-approval (the executor approves its private endpoint manually instead)"
  }
}

run "outpost_scan_network_builds_network_and_private_endpoint" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  # A resource group ID is only known after apply; pin it to compare scopes.
  override_resource {
    target          = azurerm_resource_group.dspm_sql_managed_instance
    override_during = plan
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/upwind-cs-sqlmi-rg-org_test"
    }
  }

  assert {
    condition = alltrue([
      for a in [
        "Microsoft.Network/virtualNetworks/write",
        "Microsoft.Network/virtualNetworks/subnets/write",
        "Microsoft.Network/networkSecurityGroups/write",
        "Microsoft.Network/routeTables/write",
        "Microsoft.Network/privateEndpoints/write",
        "Microsoft.Network/privateDnsZones/write",
      ] : contains(azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions, a)
    ])
    error_message = "Outpost Scan Network must let the executor build the scan network and its private endpoint and DNS"
  }
  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_scan_network[0].scope == azurerm_resource_group.dspm_sql_managed_instance[0].id && azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator[0].scope == azurerm_resource_group.dspm_sql_managed_instance[0].id
    error_message = "both RG-scoped DSPM roles must be assigned on the single scan RG"
  }
}

# Offboarding must be able to empty the scan RG (instance, endpoint, network) in
# both modes, so destroy only deletes an empty RG. The subscription-wide join
# role only joins. (In Outpost the principal's deployer role grants wider
# network rights anyway; these assert what the DSPM roles themselves grant.)
run "scan_network_can_empty_the_rg_and_join_role_only_joins" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = alltrue([
      for a in [
        "Microsoft.Network/virtualNetworks/delete",
        "Microsoft.Network/virtualNetworks/subnets/delete",
        "Microsoft.Network/networkSecurityGroups/delete",
        "Microsoft.Network/routeTables/delete",
        "Microsoft.Network/privateEndpoints/delete",
        "Microsoft.Network/privateDnsZones/delete",
        "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
      ] : contains(azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions, a)
    ])
    error_message = "Scan Network must let offboarding delete the scan network, private endpoint and DNS, so the RG ends up empty"
  }
  assert {
    condition = alltrue([
      for a in azurerm_role_definition.dspm_sql_managed_instance_network_join[0].permissions[0].actions : endswith(a, "/join/action")
    ])
    error_message = "the subscription-wide DSPM join role must only grant join actions"
  }
}

run "saas_uses_snapshot_sp_without_private_endpoint_rights" {
  command = plan
  variables {
    saas_enabled                                           = true
    snapshot_app_service_principal_object_id               = "00000000-0000-0000-0000-00000000000a"
    fetcher_app_service_principal_object_id                = "00000000-0000-0000-0000-00000000000b"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = alltrue([
      azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator[0].principal_id == "00000000-0000-0000-0000-00000000000a",
      azurerm_role_assignment.dspm_sql_managed_instance_scan_network[0].principal_id == "00000000-0000-0000-0000-00000000000a",
    ])
    error_message = "SaaS assigns the DSPM roles to the Snapshot app's service principal"
  }
  assert {
    condition = length([
      for a in azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions : a
      if startswith(a, "Microsoft.Network/privateEndpoints/") || startswith(a, "Microsoft.Network/privateDnsZones/")
    ]) == 0
    error_message = "in SaaS the private endpoint and DNS live in Upwind's subscription, so no rights on them here"
  }
  assert {
    condition = alltrue([
      for a in [
        "Microsoft.Network/virtualNetworks/delete",
        "Microsoft.Network/virtualNetworks/subnets/delete",
        "Microsoft.Network/networkSecurityGroups/delete",
        "Microsoft.Network/routeTables/delete",
      ] : contains(azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions, a)
    ])
    error_message = "in SaaS the Snapshot app has no deployer role, so Scan Network must let offboarding delete the scan network, or destroy finds a non-empty RG"
  }
  assert {
    condition     = length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0 && length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0
    error_message = "SaaS gets no subscription-wide join (its worker is in Upwind's tenant)"
  }
}

run "enabled_without_cloudscanner_creates_nothing_and_warns" {
  command = plan
  variables {
    scanner_client_id                                      = ""
    scanner_client_secret                                  = ""
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }
  expect_failures = [check.dspm_sql_managed_instance_needs_cloudscanner]

  assert {
    condition = (
      length(azurerm_resource_group.dspm_sql_managed_instance) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0 &&
      length(time_sleep.dspm_sql_managed_instance_role_definition_wait) == 0
    )
    error_message = "Outpost without CloudScanner has no worker to scan the copies, so nothing is created"
  }
}

# Either DSPM opt-out wins over the SQL flag, as for every other DSPM grant
# (local.dspm_enabled).
run "dspm_opt_out_wins" {
  command = plan
  variables {
    upwind_feature_dspm_enabled                            = false
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = (
      length(azurerm_resource_group.dspm_sql_managed_instance) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0
    )
    error_message = "with upwind_feature_dspm_enabled = false no SQL DSPM roles may be granted, whatever upwind_feature_dspm_azure_sql_managed_instance_enabled says"
  }
}

run "legacy_dspm_opt_out_wins" {
  command = plan
  variables {
    disable_function_scanning                              = true
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = (
      length(azurerm_resource_group.dspm_sql_managed_instance) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_instance_operator) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_scan_network) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0
    )
    error_message = "with the legacy disable_function_scanning = true no SQL DSPM roles may be granted, whatever upwind_feature_dspm_azure_sql_managed_instance_enabled says"
  }
}

# The definition wait has triggers, so it waits again when a definition is added
# later: here the join role, which only Outpost has (a move from SaaS to Outpost
# adds it while the wait is already in state).
run "role_definition_wait_tracks_every_definition" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }
  override_resource {
    target          = azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator
    override_during = plan
    values          = { role_definition_id = "11111111-0000-0000-0000-000000000001" }
  }
  override_resource {
    target          = azurerm_role_definition.dspm_sql_managed_instance_scan_network
    override_during = plan
    values          = { role_definition_id = "11111111-0000-0000-0000-000000000002" }
  }
  override_resource {
    target          = azurerm_role_definition.dspm_sql_managed_instance_network_join
    override_during = plan
    values          = { role_definition_id = "11111111-0000-0000-0000-000000000003" }
  }

  assert {
    condition = jsondecode(time_sleep.dspm_sql_managed_instance_role_definition_wait[0].triggers.definitions) == [
      "11111111-0000-0000-0000-000000000001",
      "11111111-0000-0000-0000-000000000002",
      "11111111-0000-0000-0000-000000000003",
    ]
    error_message = "the definition wait must be triggered by every definition, the Outpost join role included, so adding one later waits again"
  }
}

# Turning the feature off while the scan RG still holds anything removes the
# roles Upwind needs to delete it: warn. A scan instance (billed):
run "feature_off_with_scan_instance_left_warns" {
  command = plan
  override_data {
    target = data.azurerm_resources.dspm_sql_managed_instance_scan_rg["Microsoft.Sql/managedInstances"]
    values = {
      resources = [{
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/upwind-cs-sqlmi-rg-org_test/providers/Microsoft.Sql/managedInstances/scan-westus3"
        name                = "scan-westus3"
        type                = "Microsoft.Sql/managedInstances"
        location            = "westus3"
        resource_group_name = "upwind-cs-sqlmi-rg-org_test"
        tags                = {}
      }]
    }
  }
  expect_failures = [check.dspm_sql_managed_instance_offboard_first]
}

# Only network, left by a failed first scan or a partial offboarding: it still
# blocks the RG delete.
run "feature_off_with_network_left_warns" {
  command = plan
  override_data {
    target = data.azurerm_resources.dspm_sql_managed_instance_scan_rg["Microsoft.Network/networkSecurityGroups"]
    values = {
      resources = [{
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/upwind-cs-sqlmi-rg-org_test/providers/Microsoft.Network/networkSecurityGroups/scan-westus3-nsg"
        name                = "scan-westus3-nsg"
        type                = "Microsoft.Network/networkSecurityGroups"
        location            = "westus3"
        resource_group_name = "upwind-cs-sqlmi-rg-org_test"
        tags                = {}
      }]
    }
  }
  expect_failures = [check.dspm_sql_managed_instance_offboard_first]
}

# With the feature on, the scan RG's contents are expected: no warning.
run "feature_on_with_scan_instance_does_not_warn" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }
  override_data {
    target = data.azurerm_resources.dspm_sql_managed_instance_scan_rg["Microsoft.Sql/managedInstances"]
    values = {
      resources = [{
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/upwind-cs-sqlmi-rg-org_test/providers/Microsoft.Sql/managedInstances/scan-westus3"
        name                = "scan-westus3"
        type                = "Microsoft.Sql/managedInstances"
        location            = "westus3"
        resource_group_name = "upwind-cs-sqlmi-rg-org_test"
        tags                = {}
      }]
    }
  }
}

# Resources of the same types elsewhere in the subscription don't count.
run "feature_off_other_rg_does_not_warn" {
  command = plan
  override_data {
    target = data.azurerm_resources.dspm_sql_managed_instance_scan_rg["Microsoft.Network/virtualNetworks"]
    values = {
      resources = [{
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/customer-network-rg/providers/Microsoft.Network/virtualNetworks/hub-vnet"
        name                = "hub-vnet"
        type                = "Microsoft.Network/virtualNetworks"
        location            = "westus3"
        resource_group_name = "customer-network-rg"
        tags                = {}
      }]
    }
  }
}
