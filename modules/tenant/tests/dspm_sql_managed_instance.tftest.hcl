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
      length(azurerm_role_definition.dspm_sql_managed_instance_network_join) == 0 &&
      length(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0
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
        "Microsoft.Sql/managedInstances/validateAzureKeyVaultEncryptionKey/action",
        "Microsoft.ManagedIdentity/userAssignedIdentities/read",
        "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",
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
    condition = alltrue([
      for a in ["Microsoft.Sql/managedInstances/keys/read", "Microsoft.Sql/managedInstances/keys/write"] :
      contains(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].permissions[0].actions, a)
    ])
    error_message = "the executor must be able to register a source's TDE key on the scan instance (not yet shown unnecessary, UP-14344)"
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
    dspm_sql_managed_instances                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi"]
    dspm_sql_tde_key_vault_ids                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1"]
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
      length(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 0 &&
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
    dspm_sql_managed_instances                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi"]
    dspm_sql_tde_key_vault_ids                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1"]
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
      length(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0
    )
    error_message = "with upwind_feature_dspm_enabled = false no SQL DSPM roles may be granted, whatever upwind_feature_dspm_azure_sql_managed_instance_enabled says"
  }
}

run "legacy_dspm_opt_out_wins" {
  command = plan
  variables {
    disable_function_scanning                              = true
    dspm_sql_managed_instances                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi"]
    dspm_sql_tde_key_vault_ids                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1"]
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
      length(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 0 &&
      length(azurerm_role_assignment.dspm_sql_managed_instance_network_join) == 0
    )
    error_message = "with the legacy disable_function_scanning = true no SQL DSPM roles may be granted, whatever upwind_feature_dspm_azure_sql_managed_instance_enabled says"
  }
}

# Source side (Account A): a read-only Backup Reader role on the customer's
# source managed instances, for the same principal as the orchestrator-side
# roles. By default at the CloudScanner scopes (like the storage DSPM readers),
# so new instances need no Terraform change; with an allowlist, per instance.
run "backup_reader_defaults_to_the_cloudscanner_scopes" {
  command = plan
  variables {
    azure_application_client_id                            = "00000000-0000-0000-0000-0000000000c1"
    azure_application_client_secret                        = "existing-app-secret-value"
    azure_application_service_principal_object_id          = "00000000-0000-0000-0000-0000000000c2"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition     = keys(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == ["/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000002"]
    error_message = "with no allowlist, Backup Reader is defined at each CloudScanner scope (here the tenant root management group)"
  }
  assert {
    condition = alltrue([
      for k, a in azurerm_role_assignment.dspm_sql_managed_instance_backup_reader :
      a.scope == "/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000002" && a.principal_id == "00000000-0000-0000-0000-0000000000c2"
    ]) && length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 1
    error_message = "with no allowlist, Backup Reader is assigned at the CloudScanner scope to the onboarding service principal"
  }
  assert {
    condition = toset(azurerm_role_definition.dspm_sql_managed_instance_backup_reader["/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000002"].permissions[0].actions) == toset([
      "Microsoft.Sql/managedInstances/read",
      "Microsoft.Sql/managedInstances/databases/read",
      "Microsoft.Sql/managedInstances/databases/readBackups/action",
      "Microsoft.Sql/managedInstances/encryptionProtector/read",
      "Microsoft.Sql/managedInstances/keys/read",
    ])
    error_message = "Backup Reader must grant exactly the five read-only source actions"
  }
}

run "backup_reader_follows_included_subscriptions" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    cloudscanner_include_subscriptions                     = ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"]
  }

  assert {
    condition = toset(keys(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader)) == toset([
      "/subscriptions/11111111-1111-1111-1111-111111111111",
      "/subscriptions/22222222-2222-2222-2222-222222222222",
    ])
    error_message = "with no allowlist, Backup Reader follows the CloudScanner scopes, including an include-subscriptions filter"
  }
}

run "backup_reader_allowlist_is_per_instance" {
  command = plan
  variables {
    azure_application_client_id                            = "00000000-0000-0000-0000-0000000000c1"
    azure_application_client_secret                        = "existing-app-secret-value"
    azure_application_service_principal_object_id          = "00000000-0000-0000-0000-0000000000c2"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_managed_instances = [
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi",
      "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-hr/providers/Microsoft.Sql/managedInstances/hr-mi",
    ]
  }

  assert {
    condition     = keys(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == ["/subscriptions/00000000-0000-0000-0000-000000000000"]
    error_message = "with an allowlist, Backup Reader is defined once, in the orchestrator subscription"
  }
  assert {
    condition = toset(azurerm_role_definition.dspm_sql_managed_instance_backup_reader["/subscriptions/00000000-0000-0000-0000-000000000000"].assignable_scopes) == toset([
      "/subscriptions/00000000-0000-0000-0000-000000000000",
      "/subscriptions/11111111-1111-1111-1111-111111111111",
      "/subscriptions/22222222-2222-2222-2222-222222222222",
    ])
    error_message = "with an allowlist, Backup Reader is assignable in each listed instance's subscription (and the orchestrator subscription it is defined in)"
  }
  assert {
    condition = toset([for a in azurerm_role_assignment.dspm_sql_managed_instance_backup_reader : a.scope]) == toset([
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi",
      "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-hr/providers/Microsoft.Sql/managedInstances/hr-mi",
    ])
    error_message = "with an allowlist, Backup Reader is assigned on each listed instance only, not its subscription or the CloudScanner scopes"
  }
  assert {
    condition     = alltrue([for k, a in azurerm_role_assignment.dspm_sql_managed_instance_backup_reader : a.principal_id == "00000000-0000-0000-0000-0000000000c2"])
    error_message = "in Outpost Backup Reader goes to the onboarding service principal, like the orchestrator-side roles"
  }
}

run "backup_reader_allowlist_role_id_and_case" {
  command = plan
  variables {
    azure_application_client_id                            = "00000000-0000-0000-0000-0000000000c1"
    azure_application_client_secret                        = "existing-app-secret-value"
    azure_application_service_principal_object_id          = "00000000-0000-0000-0000-0000000000c2"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_managed_instances = [
      "/subscriptions/AAAAAAAA-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi",
      "/subscriptions/aaaaaaaa-1111-1111-1111-111111111111/resourcegroups/RG-DATA/providers/microsoft.sql/managedinstances/SALES-MI",
    ]
  }

  override_resource {
    target          = azurerm_role_definition.dspm_sql_managed_instance_backup_reader
    override_during = plan
    values = {
      role_definition_id = "99999999-9999-9999-9999-999999999999"
    }
  }

  assert {
    condition = keys(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == [
      "/subscriptions/aaaaaaaa-1111-1111-1111-111111111111/resourcegroups/rg-data/providers/microsoft.sql/managedinstances/sales-mi",
    ]
    error_message = "the same instance listed twice in different case must give one assignment, keyed by the lower-cased ID, so re-casing an entry replaces its assignment in place instead of racing a create against a destroy on the same scope"
  }
  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_backup_reader["/subscriptions/aaaaaaaa-1111-1111-1111-111111111111/resourcegroups/rg-data/providers/microsoft.sql/managedinstances/sales-mi"].scope == "/subscriptions/AAAAAAAA-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi"
    error_message = "the assignment's scope keeps the first spelling given"
  }
  assert {
    condition = toset(azurerm_role_definition.dspm_sql_managed_instance_backup_reader["/subscriptions/00000000-0000-0000-0000-000000000000"].assignable_scopes) == toset([
      "/subscriptions/00000000-0000-0000-0000-000000000000",
      "/subscriptions/aaaaaaaa-1111-1111-1111-111111111111",
    ])
    error_message = "assignable scopes must use lower-case subscription IDs, as Azure returns them"
  }
  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_backup_reader["/subscriptions/aaaaaaaa-1111-1111-1111-111111111111/resourcegroups/rg-data/providers/microsoft.sql/managedinstances/sales-mi"].role_definition_id == "/subscriptions/aaaaaaaa-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/99999999-9999-9999-9999-999999999999"
    error_message = "an allowlist assignment must refer to the role under the instance's own subscription, not the orchestrator subscription it is defined in"
  }
}

run "saas_backup_reader_goes_to_snapshot_sp" {
  command = plan
  variables {
    saas_enabled                                           = true
    snapshot_app_service_principal_object_id               = "00000000-0000-0000-0000-00000000000a"
    fetcher_app_service_principal_object_id                = "00000000-0000-0000-0000-00000000000b"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition     = azurerm_role_assignment.dspm_sql_managed_instance_backup_reader["/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000002"].principal_id == "00000000-0000-0000-0000-00000000000a"
    error_message = "in SaaS Backup Reader goes to the Snapshot app's service principal, at the same scopes as its other scanning roles"
  }
}

run "no_backup_reader_with_flag_off" {
  command = plan
  variables {
    dspm_sql_managed_instances = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/managedInstances/sales-mi"]
  }

  assert {
    condition     = length(azurerm_role_definition.dspm_sql_managed_instance_backup_reader) == 0 && length(azurerm_role_assignment.dspm_sql_managed_instance_backup_reader) == 0
    error_message = "nothing is granted while upwind_feature_dspm_azure_sql_managed_instance_enabled is false, whatever dspm_sql_managed_instances says"
  }
}

run "rejects_non_managed_instance_ids" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_managed_instances = [
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-data/providers/Microsoft.Sql/servers/sales-sql",
    ]
  }
  expect_failures = [var.dspm_sql_managed_instances]
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

# region Customer-managed TDE keys

# The scan instances' identity: created once a vault is listed, in the scan RG,
# under the fixed name the executor derives from the org ID.
run "tde_identity_in_scan_rg_with_fixed_name" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_tde_key_vault_ids                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1"]
  }

  assert {
    condition = (
      azurerm_user_assigned_identity.dspm_sql_managed_instance_tde[0].name == "upwind-cs-sqlmi-scan-identity-org_test" &&
      azurerm_user_assigned_identity.dspm_sql_managed_instance_tde[0].resource_group_name == "upwind-cs-sqlmi-rg-org_test"
    )
    error_message = "the TDE identity is upwind-cs-sqlmi-scan-identity-<orgId> in upwind-cs-sqlmi-rg-<orgId> (the executor derives both)"
  }
}

# All sources on service-managed keys: no identity, so the scan instances keep
# their own primary identity, and SaaS needs no Microsoft.ManagedIdentity.
run "no_tde_identity_without_vaults" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 && length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0
    error_message = "with no vaults listed, no identity and no vault grants"
  }
  assert {
    condition     = length(azurerm_resource_group.dspm_sql_managed_instance) == 1 && length(azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator) == 1
    error_message = "the rest of SQL MI DSPM is unaffected by an empty vault list"
  }
}

run "saas_creates_the_tde_identity_too" {
  command = plan
  variables {
    saas_enabled                                           = true
    snapshot_app_service_principal_object_id               = "00000000-0000-0000-0000-00000000000a"
    fetcher_app_service_principal_object_id                = "00000000-0000-0000-0000-00000000000b"
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_tde_key_vault_ids                             = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1"]
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 1
    error_message = "SaaS scan instances live in the customer's orchestrator subscription too, so they need the same identity"
  }
}

# One grant per vault, at vault scope, to the identity's principal; the same
# vault in two spellings is one grant.
run "tde_key_vault_grants_per_vault" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_tde_key_vault_ids = [
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1",
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/RG-KEYS/providers/microsoft.keyvault/vaults/KV-TDE-1",
      "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-old/providers/Microsoft.KeyVault/vaults/kv-tde-old",
    ]
  }
  override_resource {
    target          = azurerm_user_assigned_identity.dspm_sql_managed_instance_tde
    override_during = plan
    values          = { principal_id = "00000000-0000-0000-0000-0000000000d1" }
  }

  assert {
    condition = toset([for a in azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault : a.scope]) == toset([
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1",
      "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-old/providers/Microsoft.KeyVault/vaults/kv-tde-old",
    ]) && length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 2
    error_message = "one grant per vault at vault scope, de-duplicated case-insensitively keeping the first spelling"
  }
  assert {
    condition = toset(keys(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault)) == toset([
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/rg-keys/providers/microsoft.keyvault/vaults/kv-tde-1",
      "/subscriptions/22222222-2222-2222-2222-222222222222/resourcegroups/rg-old/providers/microsoft.keyvault/vaults/kv-tde-old",
    ])
    error_message = "grants are keyed by the lower-cased vault ID, so re-casing a listed vault keeps its grant instead of racing a destroy and a create on the same scope"
  }
  assert {
    condition = alltrue([
      for a in azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault :
      a.role_definition_name == "Key Vault Crypto Service Encryption User" &&
      a.principal_id == "00000000-0000-0000-0000-0000000000d1" &&
      a.principal_type == "ServicePrincipal"
    ])
    error_message = "each vault grants Key Vault Crypto Service Encryption User to the TDE identity, never to the executor's principal"
  }
}

run "no_tde_grants_with_flag_off" {
  command = plan
  variables {
    dspm_sql_tde_key_vault_ids = [
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/vaults/kv-tde-1",
    ]
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.dspm_sql_managed_instance_tde) == 0 && length(azurerm_role_assignment.dspm_sql_managed_instance_tde_key_vault) == 0
    error_message = "vaults listed without the feature on grant nothing"
  }
}

run "rejects_managed_hsm" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_tde_key_vault_ids = [
      "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-keys/providers/Microsoft.KeyVault/managedHSMs/hsm-1",
    ]
  }
  expect_failures = [var.dspm_sql_tde_key_vault_ids]
}

run "rejects_key_ids" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
    dspm_sql_tde_key_vault_ids = [
      "https://kv-tde-1.vault.azure.net/keys/tde/0123456789abcdef0123456789abcdef",
    ]
  }
  expect_failures = [var.dspm_sql_tde_key_vault_ids]
}

# The TDE identity can unwrap the customer's keys, so whoever can attach it to
# compute and sign in as it gets that access. The DSPM roles never add compute
# (or any other namespace that can host code): every action is Microsoft.Sql or
# Microsoft.Network, reading the RG, or attaching the identity, which the scan
# instance needs. In Outpost the CloudScanner deployer role already grants
# compute and assign/action subscription-wide (see the module comment); that is
# outside these roles.
run "dspm_roles_grant_no_compute" {
  command = plan
  variables {
    upwind_feature_dspm_azure_sql_managed_instance_enabled = true
  }

  assert {
    condition = alltrue([
      for a in concat(
        azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].permissions[0].actions,
        azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions,
        azurerm_role_definition.dspm_sql_managed_instance_network_join[0].permissions[0].actions,
      ) :
      startswith(a, "Microsoft.Sql/") || startswith(a, "Microsoft.Network/") ||
      contains([
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.ManagedIdentity/userAssignedIdentities/read",
        "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",
      ], a)
    ])
    error_message = "the DSPM orchestrator roles may only grant Microsoft.Sql, Microsoft.Network, RG read and identity read and assign actions: anything that can run code could sign in as the TDE identity"
  }
  assert {
    condition = alltrue([
      for a in concat(
        azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].permissions[0].actions,
        azurerm_role_definition.dspm_sql_managed_instance_network_join[0].permissions[0].actions,
      ) : !startswith(a, "Microsoft.ManagedIdentity/")
    ])
    error_message = "only the Scan Instance Operator role, on the scan RG, may attach the TDE identity"
  }
}

# endregion
