# region DSPM: Azure SQL Managed Instance, orchestrator side (Account B)
#
# Azure SQL MI DSPM never connects to the customer's production instance. A
# point-in-time restore copies each database into an Upwind-owned scan managed
# instance in the orchestrator subscription (one per region, shared by every
# source instance in that region), the worker samples the copy through a private
# endpoint, and the copy is dropped. Design: Confluence "Azure SQL DSPM",
# Permissions / Networking / Onboarding Terraform.
#
# This file provisions only what has to exist before the first scan:
#   * one resource group, upwind-cs-sqlmi-rg-<orgId>, for the scan instances and
#     everything the executor creates around them;
#   * the custom roles the restore executor needs, and their assignments.
# Everything else is created by the executor on the first scan in a region: the
# scan instance's VNet, delegated subnet, NSG and route table, the instance
# itself, and (Outpost) its private endpoint and private DNS zone. So no list of
# regions is needed here: the network follows the regions actually scanned.
# The source side (Account A: read-only access to each source instance's
# backups) is granted separately.
#
# Identity: the restore executor runs outside the customer's tenant in both
# modes, so it signs in as a principal Upwind can already authenticate as from
# outside:
#   * Outpost: it runs in Upwind's Argo cluster next to the scanner's scaler, as
#     the onboarding service principal (local.service_principal_object_id): the
#     WIF Fetcher app's SP (via azure-auth-service) or, in the legacy flow, the
#     onboarding app whose secret Upwind holds. The same principal the scaler uses.
#   * SaaS: it runs beside the SaaS scaler in Upwind's subscription (C), as the
#     existing Snapshot app's service principal (no new app, no new consent).
#     Its private endpoint and DNS live in Upwind's subscription (C), so here it
#     only gets what it needs to build and remove the scan instance's own
#     network, confined to the scan RG.
# No identity is created here, so nothing has to be handed back to Upwind.
#
# Effective access in Outpost: the onboarding service principal also holds the
# CloudScanner deployer role (Microsoft.Network/* and more on the orchestrator
# subscription), so in Outpost these roles don't narrow what it can do on the
# network. They are still granted, so DSPM states exactly what it needs and
# keeps working if the deployer role is ever narrowed. In SaaS they are the
# Snapshot app's only rights in the orchestrator subscription beyond read.
#
# Offboarding: Upwind's scanner/org offboarding discards the scan instance and
# its associated resources (private endpoints, then the instance, then the
# network) with this same principal, while the roles still exist. That is why
# the roles can delete them: the RG only ever holds Upwind's own resources. The
# RG itself stays with Terraform, so destroy finds it empty. The order matters:
# turning the feature off first removes the roles and strands whatever is still
# in the RG (see the dspm_sql_managed_instance_offboard_first check).
#
# Deliberately NOT granted: privateEndpointConnectionsApproval/action and the
# managedInstances/*/action wildcard it would need (the executor creates the
# endpoint as a manual request and approves it with
# privateEndpointConnections/write instead).

locals {
  # Requires DSPM to be enabled too (local.dspm_enabled, like every other DSPM
  # grant: upwind_feature_dspm_enabled and not the legacy
  # disable_function_scanning), so a customer who turned DSPM off by either
  # control gets no SQL DSPM roles. Outpost also needs CloudScanner: without it
  # there is no worker to scan the copies (see the check block below).
  dspm_sql_managed_instance_requested = var.upwind_feature_dspm_azure_sql_managed_instance_enabled && local.dspm_enabled
  dspm_sql_managed_instance_enabled   = local.dspm_sql_managed_instance_requested && (var.saas_enabled || local.cloudscanner_enabled)
  dspm_sql_managed_instance_outpost   = local.dspm_sql_managed_instance_enabled && !var.saas_enabled

  # Principal holding the orchestrator-side roles.
  dspm_sql_managed_instance_principal_id = local.dspm_sql_managed_instance_enabled ? (
    var.saas_enabled ? local.saas_snapshot_sp_object_id : local.service_principal_object_id
  ) : null

  # Upwind DSPM Scan Instance Operator, on the scan RG only. Its Microsoft.Sql
  # actions only reach the scan instances in it, never the network.
  dspm_sql_managed_instance_scan_instance_operator_actions = [
    "Microsoft.Sql/managedInstances/read",
    "Microsoft.Sql/managedInstances/write",
    "Microsoft.Sql/managedInstances/start/action",
    "Microsoft.Sql/managedInstances/stop/action",
    # Discard the scan instance on scanner/org offboarding. The executor itself
    # never deletes it during scanning.
    "Microsoft.Sql/managedInstances/delete",
    "Microsoft.Sql/managedInstances/databases/read",
    "Microsoft.Sql/managedInstances/databases/write",
    "Microsoft.Sql/managedInstances/databases/delete",
    # Accept a restore whose source is in another subscription (Account A).
    "Microsoft.Sql/managedInstances/crossSubscriptionPITR/action",
    # Entra admin and Entra-only sign-in, set once when the instance is created.
    "Microsoft.Sql/managedInstances/administrators/read",
    "Microsoft.Sql/managedInstances/administrators/write",
    "Microsoft.Sql/managedInstances/azureADOnlyAuthentications/read",
    "Microsoft.Sql/managedInstances/azureADOnlyAuthentications/write",
    # Register a source's customer-managed TDE key on the scan instance.
    "Microsoft.Sql/managedInstances/keys/read",
    "Microsoft.Sql/managedInstances/keys/write",
    # Manual approval of the executor's own private endpoint.
    "Microsoft.Sql/managedInstances/privateEndpointConnections/read",
    "Microsoft.Sql/managedInstances/privateEndpointConnections/write",
    # Long-running operation status. managedDatabaseAzureAsyncOperation/read is
    # checked by ARM but is not a published operation, so only the wildcard works.
    "Microsoft.Sql/locations/*/read",
  ]

  # Upwind DSPM Scan Network, on the same scan RG. Building the scan instance's
  # network (VNet, delegated subnet, NSG and route table, which the instance then
  # joins), and deleting it again on offboarding so the RG ends up empty. Its
  # Microsoft.Network actions never reach the instances. Kept as a separate role
  # from the operator so each set of actions says what it's for, and so SaaS can
  # leave out the private endpoint and DNS actions.
  dspm_sql_managed_instance_scan_network_actions = [
    # The Azure CLI reads the RG before creating a private DNS zone.
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Network/virtualNetworks/read",
    "Microsoft.Network/virtualNetworks/write",
    "Microsoft.Network/virtualNetworks/delete",
    "Microsoft.Network/virtualNetworks/join/action",
    "Microsoft.Network/virtualNetworks/subnets/read",
    "Microsoft.Network/virtualNetworks/subnets/write",
    "Microsoft.Network/virtualNetworks/subnets/delete",
    "Microsoft.Network/virtualNetworks/subnets/join/action",
    "Microsoft.Network/networkSecurityGroups/read",
    "Microsoft.Network/networkSecurityGroups/write",
    "Microsoft.Network/networkSecurityGroups/delete",
    "Microsoft.Network/networkSecurityGroups/join/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write",
    "Microsoft.Network/routeTables/delete",
    "Microsoft.Network/routeTables/join/action",
  ]

  # Outpost only: the private endpoint and its DNS are in the customer's tenant
  # (in SaaS they are in Upwind's subscription C, so these are not granted).
  # Deletes are for offboarding.
  dspm_sql_managed_instance_scan_network_private_endpoint_actions = [
    "Microsoft.Network/privateEndpoints/read",
    "Microsoft.Network/privateEndpoints/write",
    "Microsoft.Network/privateEndpoints/delete",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
    "Microsoft.Network/privateDnsZones/read",
    "Microsoft.Network/privateDnsZones/write",
    "Microsoft.Network/privateDnsZones/delete",
    "Microsoft.Network/privateDnsZones/join/action",
    "Microsoft.Network/privateDnsZones/A/read",
    "Microsoft.Network/privateDnsZones/A/write",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
  ]

  # Outpost only: join rights on the worker's network. The private endpoint goes
  # into the worker's subnet and the DNS zone is linked to the worker's VNet; both
  # are created per scanner by the CloudScanner deployment in its own RG, unknown
  # at onboarding, so this is assigned on the orchestrator subscription. The role
  # itself only joins; see "Effective access in Outpost" above.
  dspm_sql_managed_instance_network_join_actions = [
    "Microsoft.Network/virtualNetworks/subnets/join/action",
    "Microsoft.Network/virtualNetworks/join/action",
  ]
}

# Outpost without CloudScanner gets nothing (no worker to scan the copies). Warn
# rather than silently creating nothing.
check "dspm_sql_managed_instance_needs_cloudscanner" {
  assert {
    condition     = !local.dspm_sql_managed_instance_requested || var.saas_enabled || local.cloudscanner_enabled
    error_message = "upwind_feature_dspm_azure_sql_managed_instance_enabled is true, but CloudScanner isn't enabled (set scanner_client_id, or key_vault_private_network), so no Azure SQL MI DSPM resources were created: without CloudScanner there is no worker to scan the restored copies."
  }
}

# Turning the feature off removes the executor's roles before Terraform tries
# to delete the RG, so anything still in it is stranded: the RG delete fails
# (prevent_deletion_if_contains_resources) and Upwind can no longer remove it. A
# scan instance keeps billing; network left by a failed first scan or a partial
# offboarding blocks the delete too. Warn while the feature is off and the RG
# isn't empty. terraform destroy doesn't run check blocks, so there is no warning
# on destroy (see the module README).
#
# Lists each type that can end up in the RG (what the executor's roles can
# create, plus the virtual cluster Azure keeps while it holds a deleted
# instance's subnet) across the orchestrator subscription. Not by RG name, which
# fails for an RG that doesn't exist (every plan where the feature was never
# on), and not the whole subscription, which would page through every resource
# in it on every plan. Top-level rather than inside the check, which allows only
# one data source and no for_each.
locals {
  dspm_sql_managed_instance_scan_rg_name = "upwind-cs-sqlmi-rg-${var.upwind_organization_id}"
  dspm_sql_managed_instance_scan_rg_types = toset([
    "Microsoft.Sql/managedInstances",
    "Microsoft.Sql/virtualClusters",
    "Microsoft.Network/virtualNetworks",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/routeTables",
    "Microsoft.Network/privateEndpoints",
    "Microsoft.Network/privateDnsZones",
  ])
  dspm_sql_managed_instance_scan_rg_contents = sort(flatten([
    for type, found in data.azurerm_resources.dspm_sql_managed_instance_scan_rg : [
      for r in found.resources : "${type}/${r.name}"
      if lower(split("/", r.id)[4]) == lower(local.dspm_sql_managed_instance_scan_rg_name)
    ]
  ]))
}

data "azurerm_resources" "dspm_sql_managed_instance_scan_rg" {
  for_each = local.dspm_sql_managed_instance_scan_rg_types
  type     = each.value
}

check "dspm_sql_managed_instance_offboard_first" {
  assert {
    condition     = local.dspm_sql_managed_instance_enabled || length(local.dspm_sql_managed_instance_scan_rg_contents) == 0
    error_message = "Azure SQL MI DSPM is off, but ${local.dspm_sql_managed_instance_scan_rg_name} still holds: ${join(", ", local.dspm_sql_managed_instance_scan_rg_contents)}. Applying removes the roles Upwind needs to delete them, the resource group delete then fails, and a scan instance keeps billing. Keep the feature on (upwind_feature_dspm_azure_sql_managed_instance_enabled, with DSPM enabled) until the scanners/org are offboarded in Upwind, which empties the RG, then turn it off. If the roles are already gone, either turn the feature back on and offboard in Upwind, or delete the RG yourself."
  }
}

# region Resource group

# Holds each region's scan instance and its network, and in Outpost the private
# endpoints and private DNS zones, all created by the executor and removed by
# Upwind's offboarding. If destroy has to delete them itself, Azure holds a
# managed instance subnet for up to ~90 minutes after the last instance in it is
# removed (virtual cluster teardown), so deleting this RG may need a retry.
resource "azurerm_resource_group" "dspm_sql_managed_instance" {
  count    = local.dspm_sql_managed_instance_enabled ? 1 : 0
  name     = "upwind-cs-sqlmi-rg-${var.upwind_organization_id}"
  location = var.azure_cloudscanner_location
  tags     = var.tags

  lifecycle {
    # The RG's own location is only metadata: the scan instances in it are
    # created in each scanned region. Changing azure_cloudscanner_location
    # later must not replace the RG (and with it its roles and every instance).
    ignore_changes = [location]
  }
}

# endregion

# region Roles

resource "azurerm_role_definition" "dspm_sql_managed_instance_scan_instance_operator" {
  count       = local.dspm_sql_managed_instance_enabled ? 1 : 0
  name        = "UpwindDSPMSQLMIScanInstanceOperator-${local.resource_suffix}"
  description = "Upwind DSPM: create, start, stop and (on offboarding) delete the Azure SQL scan managed instance, restore point-in-time copies onto it and drop them."
  scope       = azurerm_resource_group.dspm_sql_managed_instance[0].id

  permissions {
    actions     = local.dspm_sql_managed_instance_scan_instance_operator_actions
    not_actions = []
  }
}

resource "azurerm_role_definition" "dspm_sql_managed_instance_scan_network" {
  count       = local.dspm_sql_managed_instance_enabled ? 1 : 0
  name        = "UpwindDSPMSQLMIScanNetwork-${local.resource_suffix}"
  description = "Upwind DSPM: build the Azure SQL scan instance network (VNet, delegated subnet, NSG, route table)${local.dspm_sql_managed_instance_outpost ? " and its private endpoints and private DNS zones" : ""}, and delete them on offboarding."
  scope       = azurerm_resource_group.dspm_sql_managed_instance[0].id

  permissions {
    actions = concat(
      local.dspm_sql_managed_instance_scan_network_actions,
      local.dspm_sql_managed_instance_outpost ? local.dspm_sql_managed_instance_scan_network_private_endpoint_actions : [],
    )
    not_actions = []
  }
}

resource "azurerm_role_definition" "dspm_sql_managed_instance_network_join" {
  count       = local.dspm_sql_managed_instance_outpost ? 1 : 0
  name        = "UpwindDSPMSQLMINetworkJoin-${local.resource_suffix}"
  description = "Upwind DSPM: join the CloudScanner worker's subnet and VNet for the scan instance's private endpoint and DNS link. Join only."
  scope       = local.orchestrator_subscription_scope

  permissions {
    actions     = local.dspm_sql_managed_instance_network_join_actions
    not_actions = []
  }
}

resource "time_sleep" "dspm_sql_managed_instance_role_definition_wait" {
  count = local.dspm_sql_managed_instance_enabled ? 1 : 0
  depends_on = [
    azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator,
    azurerm_role_definition.dspm_sql_managed_instance_scan_network,
    azurerm_role_definition.dspm_sql_managed_instance_network_join,
  ]
  create_duration = var.azure_role_definition_wait_time
  # Wait again whenever a definition is added or replaced (e.g. the join role
  # when a deployment moves from SaaS to Outpost), not only on first create.
  triggers = {
    definitions = jsonencode(concat(
      azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[*].role_definition_id,
      azurerm_role_definition.dspm_sql_managed_instance_scan_network[*].role_definition_id,
      azurerm_role_definition.dspm_sql_managed_instance_network_join[*].role_definition_id,
    ))
  }
}

resource "azurerm_role_assignment" "dspm_sql_managed_instance_scan_instance_operator" {
  count              = local.dspm_sql_managed_instance_enabled ? 1 : 0
  role_definition_id = azurerm_role_definition.dspm_sql_managed_instance_scan_instance_operator[0].role_definition_resource_id
  principal_id       = local.dspm_sql_managed_instance_principal_id
  scope              = azurerm_resource_group.dspm_sql_managed_instance[0].id
  depends_on         = [time_sleep.dspm_sql_managed_instance_role_definition_wait[0]]
}

resource "azurerm_role_assignment" "dspm_sql_managed_instance_scan_network" {
  count              = local.dspm_sql_managed_instance_enabled ? 1 : 0
  role_definition_id = azurerm_role_definition.dspm_sql_managed_instance_scan_network[0].role_definition_resource_id
  principal_id       = local.dspm_sql_managed_instance_principal_id
  scope              = azurerm_resource_group.dspm_sql_managed_instance[0].id
  depends_on         = [time_sleep.dspm_sql_managed_instance_role_definition_wait[0]]
}

resource "azurerm_role_assignment" "dspm_sql_managed_instance_network_join" {
  count              = local.dspm_sql_managed_instance_outpost ? 1 : 0
  role_definition_id = azurerm_role_definition.dspm_sql_managed_instance_network_join[0].role_definition_resource_id
  principal_id       = local.dspm_sql_managed_instance_principal_id
  scope              = local.orchestrator_subscription_scope
  depends_on         = [time_sleep.dspm_sql_managed_instance_role_definition_wait[0]]
}

# endregion

# endregion
