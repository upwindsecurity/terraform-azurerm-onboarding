# UP-10552: the Snapshot SP's write/delete grant on the central snapshots RG is
# control-plane only. The SaaS worker snapshots the customer disk into that RG and
# copies it cross-tenant with an ARM disk create carrying an auxiliary token; it
# never exports snapshot bytes via SAS, so the Data Operator for Managed Disks
# DataActions are not needed and must not be assigned.

mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
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
}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "http" {}
mock_provider "null" {}

variables {
  upwind_organization_id                   = "org_test"
  saas_enabled                             = true
  snapshot_app_service_principal_object_id = "00000000-0000-0000-0000-00000000000a"
  fetcher_app_service_principal_object_id  = "00000000-0000-0000-0000-00000000000b"
  azure_orchestrator_subscription_id       = "00000000-0000-0000-0000-000000000000"
  azure_tenant_id                          = "00000000-0000-0000-0000-000000000002"
}

run "snapshot_rg_write_grant_is_disk_snapshot_contributor_only" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.saas_snapshot_write) == 1
    error_message = "expected exactly one write/delete role assignment on the central snapshots RG, got ${length(azurerm_role_assignment.saas_snapshot_write)}"
  }
  assert {
    condition     = azurerm_role_assignment.saas_snapshot_write["Disk Snapshot Contributor"].role_definition_name == "Disk Snapshot Contributor"
    error_message = "Disk Snapshot Contributor must be assigned on the central snapshots RG"
  }
  assert {
    condition     = !contains(keys(azurerm_role_assignment.saas_snapshot_write), "Data Operator for Managed Disks")
    error_message = "Data Operator for Managed Disks is a data-plane role no SaaS code path uses; it must not be assigned"
  }
}

run "no_data_plane_disk_role_anywhere_in_saas_mode" {
  command = plan

  assert {
    condition = length([
      for ra in concat(
        values(azurerm_role_assignment.saas_snapshot_write),
        values(azurerm_role_assignment.saas_snapshot),
        values(azurerm_role_assignment.saas_fetcher),
      ) : ra if ra.role_definition_name == "Data Operator for Managed Disks"
    ]) == 0
    error_message = "Data Operator for Managed Disks must not appear in any SaaS role assignment"
  }
}
