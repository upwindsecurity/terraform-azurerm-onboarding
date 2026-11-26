# region DSPM: Azure SQL Managed Instance
#
# Azure SQL MI DSPM never connects to the customer's production instance. A
# point-in-time restore copies each database into an Upwind-owned scan managed
# instance in the orchestrator subscription (one per region, shared by every
# source instance in that region), the worker samples the copy through a private
# endpoint, and the copy is dropped. Design: Confluence "Azure SQL DSPM",
# Permissions / Networking / Onboarding Terraform.
#
# This file provisions only what has to exist before the first scan:
#   * orchestrator side (Account B): one resource group,
#     upwind-cs-sqlmi-rg-<orgId>, for the scan instances and everything the
#     executor creates around them, and the executor's custom roles on it;
#   * only when dspm_sql_tde_key_vault_ids lists vaults (customer-managed
#     TDE): the scan instances' user-assigned identity in that RG, and its key
#     grant on each of them;
#   * source side (Account A): a read-only role on the customer's source managed
#     instances (by default at the CloudScanner scopes; optionally only on the
#     instances listed in dspm_sql_managed_instances), so the executor can
#     restore from their backups.
# Everything else is created by the executor on the first scan in a region: the
# scan instance's VNet, delegated subnet, NSG and route table, the instance
# itself, and (Outpost) its private endpoint and private DNS zone. So no list of
# regions is needed here: the network follows the regions actually scanned.
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
# The one identity created here is for the scan instances, not the executor:
# see "Customer-managed TDE keys" below. Its name is fixed, so nothing has to
# be handed back to Upwind.
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
    # Customer-managed TDE: before restoring, check the scan instance can use
    # each of the source's keys.
    "Microsoft.Sql/managedInstances/validateAzureKeyVaultEncryptionKey/action",
    # Customer-managed TDE: register a source's key on the scan instance if
    # the restore turns out to need it linked there. Not yet shown either way:
    # the lab restore that worked without registering used a key the scan
    # instance had used before (UP-14344).
    "Microsoft.Sql/managedInstances/keys/read",
    "Microsoft.Sql/managedInstances/keys/write",
    # Check whether the TDE key identity (below) exists, which it only does
    # when vaults are listed, and set it as the scan instance's primary
    # identity, at create or on an existing instance. This RG holds no other
    # identity.
    "Microsoft.ManagedIdentity/userAssignedIdentities/read",
    "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",
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
# (prevent_deletion_if_contains_resources) and Upwind can no longer remove it.
# Warn while the feature is off and a scan instance, the part that bills, is
# still in the RG. Leftover network costs next to nothing; it still blocks the
# RG delete, whose error names it. terraform destroy doesn't run check blocks,
# so there is no warning on destroy (see the module README).
#
# One list call per plan, for every customer: the subscription's managed
# instances, filtered by type in Azure (not by RG name, which fails for an RG
# that doesn't exist), then by the scan RG here. Scoped to the check, so a
# failed lookup (e.g. no read access) is a warning, never a failed plan.
locals {
  dspm_sql_managed_instance_scan_rg_name = "upwind-cs-sqlmi-rg-${var.upwind_organization_id}"
}

check "dspm_sql_managed_instance_offboard_first" {
  data "azurerm_resources" "dspm_sql_managed_instance_scan_instances" {
    type = "Microsoft.Sql/managedInstances"
  }

  assert {
    condition = local.dspm_sql_managed_instance_enabled || length([
      for r in data.azurerm_resources.dspm_sql_managed_instance_scan_instances.resources : r
      if lower(r.resource_group_name) == lower(local.dspm_sql_managed_instance_scan_rg_name)
    ]) == 0
    error_message = "Azure SQL MI DSPM is off, but ${local.dspm_sql_managed_instance_scan_rg_name} still holds the scan managed instance(s) ${join(", ", sort([for r in data.azurerm_resources.dspm_sql_managed_instance_scan_instances.resources : r.name if lower(r.resource_group_name) == lower(local.dspm_sql_managed_instance_scan_rg_name)]))}, which keep billing. Applying removes the roles Upwind needs to delete them, and the resource group delete then fails. Keep the feature on (upwind_feature_dspm_azure_sql_managed_instance_enabled, with DSPM enabled) until the scanners/org are offboarded in Upwind, which empties the RG, then turn it off. If the roles are already gone, either turn the feature back on and offboard in Upwind, or delete the RG yourself."
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
  name     = local.dspm_sql_managed_instance_scan_rg_name
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
  description = "Upwind DSPM: create, start, stop and (on offboarding) delete the Azure SQL scan managed instance, set its TDE key identity, check and register customer-managed TDE keys on it, restore point-in-time copies onto it and drop them."
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

# region Source side (Account A)
#
# A cross-subscription point-in-time restore is a single call on the scan
# instance in B, but ARM checks both crossSubscriptionPITR/action on the scan
# instance (Scan Instance Operator) and readBackups/action on the source database
# (this role), so the same principal must hold both. Read-only: nothing here can
# change or delete the customer's instances.
#
# Scope, like the storage DSPM data readers (and AWS RDS DSPM, which grants per
# account):
#   * by default (dspm_sql_managed_instances empty), at the CloudScanner scopes
#     (tenant root, management groups, or the included/excluded subscriptions),
#     so a managed instance created later is covered with no Terraform change;
#     which instances are actually scanned is chosen at runtime by the scanner's
#     capability selectors in the console. Those selectors don't limit anything
#     in Azure: with crossSubscriptionPITR on the scan instance, this lets the
#     principal restore any managed instance database under those scopes into
#     Upwind's scan instance (as the storage DSPM default lets it read any blob);
#   * with dspm_sql_managed_instances set, on each listed instance only.
#
# Key access for sources on a customer-managed TDE key is not granted here but
# to the scan instances' identity (see "Customer-managed TDE keys" below).

locals {
  # Listed instances, de-duplicated case-insensitively (ARM IDs are
  # case-insensitive, and two spellings of one instance would be two
  # assignments on the same scope, the second failing with RoleAssignmentExists),
  # keeping the first spelling given.
  dspm_sql_managed_instance_backup_reader_allowlist = local.dspm_sql_managed_instance_enabled ? toset([
    for spellings in { for id in var.dspm_sql_managed_instances : lower(id) => id... } : spellings[0]
  ]) : toset([])
  dspm_sql_managed_instance_backup_reader_broad = local.dspm_sql_managed_instance_enabled && length(var.dspm_sql_managed_instances) == 0

  # Role definitions, keyed by the scope they're defined at.
  #   * Broad: one per CloudScanner scope, assignable there (as for
  #     CloudScannerTargetRole).
  #   * Allowlist: one in the orchestrator subscription. A custom role can't list
  #     individual resources as assignable scopes, so it's assignable in each
  #     listed instance's subscription (plus the orchestrator subscription it's
  #     defined in, so its scope never depends on the list) and assigned on each
  #     instance only.
  dspm_sql_managed_instance_backup_reader_definitions = local.dspm_sql_managed_instance_backup_reader_broad ? {
    for scope in toset(local.cloudscanner_scopes) : scope => [scope]
    } : length(local.dspm_sql_managed_instance_backup_reader_allowlist) > 0 ? {
    (local.orchestrator_subscription_scope) = sort(distinct(concat(
      [local.orchestrator_subscription_scope],
      # Lower case, as Azure returns them, so a GUID given in upper case doesn't
      # show as a change on every plan.
      [for id in local.dspm_sql_managed_instance_backup_reader_allowlist : "/subscriptions/${lower(split("/", id)[2])}"],
    )))
  } : {}

  # Role assignments, with the scope each one is assigned at, the definition it
  # uses and, for the allowlist, the subscription its role ID must be built
  # under (see the assignment below). Allowlist entries are keyed by the
  # lower-cased ID: re-casing an entry then replaces its assignment in place
  # (destroy, then create) instead of adding a new key whose create can race the
  # old one's destroy and fail with RoleAssignmentExists on the same scope.
  dspm_sql_managed_instance_backup_reader_assignments = local.dspm_sql_managed_instance_backup_reader_broad ? {
    for scope in toset(local.cloudscanner_scopes) : scope => { scope = scope, definition = scope, subscription = null }
    } : {
    for id in local.dspm_sql_managed_instance_backup_reader_allowlist : lower(id) => {
      scope        = id
      definition   = local.orchestrator_subscription_scope
      subscription = lower(split("/", id)[2])
    }
  }

  # Upwind DSPM SQL MI Backup Reader.
  dspm_sql_managed_instance_backup_reader_actions = [
    # Check the source instance exists and is ready.
    "Microsoft.Sql/managedInstances/read",
    # List its databases and each one's earliest restore point.
    "Microsoft.Sql/managedInstances/databases/read",
    # Use the database's backups as the source of a cross-subscription restore.
    "Microsoft.Sql/managedInstances/databases/readBackups/action",
    # Detect a customer-managed TDE key, and which one, before restoring.
    "Microsoft.Sql/managedInstances/encryptionProtector/read",
    # List the keys registered on the source (the current protector and the
    # keys it was rotated from), so the executor can check the ones a restore
    # may need: a restore to a point after a key rotation still needs the old
    # key (tested, UP-14344). Exposes key URIs only, never key material.
    "Microsoft.Sql/managedInstances/keys/read",
  ]
}

# Also the provisioning signal for Azure SQL MI DSPM: it exists, in both modes,
# exactly when the SQL roles were granted, and Upwind detects it in the
# role-definition inventory by its name prefix, UpwindDSPMSQLMIBackupReader-{orgID}
# (no Microsoft Graph access needed). Unlike storage DSPM, whose grant is a
# built-in role and so needs the separate UpwindDSPMEnabled marker, this role's
# own name is org-specific. The prefix is a contract with that detection: a
# rename must move on both sides together.
resource "azurerm_role_definition" "dspm_sql_managed_instance_backup_reader" {
  for_each          = local.dspm_sql_managed_instance_backup_reader_definitions
  name              = "UpwindDSPMSQLMIBackupReader-${local.resource_suffix}-${split("/", each.key)[length(split("/", each.key)) - 1]}"
  description       = "Upwind DSPM: read Azure SQL managed instances and their databases, and use their backups as the source of a point-in-time restore onto Upwind's scan instance. Read-only."
  scope             = each.key
  assignable_scopes = each.value

  permissions {
    actions     = local.dspm_sql_managed_instance_backup_reader_actions
    not_actions = []
  }
}

# Its own wait, re-run whenever the definitions or their assignable scopes change
# (a new scope, or an allowlisted instance in a new subscription), so the new
# assignments wait for propagation.
resource "time_sleep" "dspm_sql_managed_instance_backup_reader_wait" {
  count           = length(local.dspm_sql_managed_instance_backup_reader_definitions) > 0 ? 1 : 0
  depends_on      = [azurerm_role_definition.dspm_sql_managed_instance_backup_reader]
  create_duration = var.azure_role_definition_wait_time
  triggers = {
    definitions = jsonencode(local.dspm_sql_managed_instance_backup_reader_definitions)
  }
}

resource "azurerm_role_assignment" "dspm_sql_managed_instance_backup_reader" {
  for_each = local.dspm_sql_managed_instance_backup_reader_assignments
  # An allowlist assignment refers to the role under the instance's own
  # subscription: the role is defined in the orchestrator subscription, but
  # Azure resolves an assignment's role ID in the subscription it's assigned in.
  role_definition_id = each.value.subscription == null ? (
    azurerm_role_definition.dspm_sql_managed_instance_backup_reader[each.value.definition].role_definition_resource_id
    ) : (
    "/subscriptions/${each.value.subscription}/providers/Microsoft.Authorization/roleDefinitions/${azurerm_role_definition.dspm_sql_managed_instance_backup_reader[each.value.definition].role_definition_id}"
  )
  principal_id = local.dspm_sql_managed_instance_principal_id
  scope        = each.value.scope
  depends_on   = [time_sleep.dspm_sql_managed_instance_backup_reader_wait[0]]
}

# endregion

# region Customer-managed TDE keys
#
# A source on a customer-managed TDE key can only be restored by a scan
# instance that can use the keys its backups were made under. The scan
# instance uses its primary identity for that, so this creates a user-assigned
# identity with a fixed name (upwind-cs-sqlmi-scan-identity-<orgId>, so the
# executor finds it without being told), grants it Key Vault Crypto Service
# Encryption User on each vault in dspm_sql_tde_key_vault_ids, and the executor
# sets it as each scan instance's primary identity (assign/action in the Scan
# Instance Operator role). Customer-facing rules (which vaults, RBAC only,
# firewall, locks, who can act as the identity): module README, "customer-
# managed TDE keys". Keep them there, not here or in the variable description.
#
# Created only when at least one vault is listed, and the executor attaches it
# only if it exists. A customer whose sources all use service-managed keys gets
# no identity and no change to the scan instance's primary identity (which the
# scan instance also uses for Entra lookups when the worker signs in). Listing
# the first vault later creates it, and the executor attaches it to existing
# scan instances. Its lifetime follows the list and the feature: emptying the
# list, or turning the feature (or DSPM, or CloudScanner in Outpost) off and on
# again, recreates it with a new principal, so vault grants only belong in the
# variable, never made directly to the identity.
#
# Who can act as the identity: in Outpost, the onboarding service principal's
# CloudScanner deployer role (Microsoft.Compute/*, Microsoft.App/*, container
# groups, deployment scripts and userAssignedIdentities/assign/action on the
# orchestrator subscription) can run code as it, as it can as the existing disk
# encryption identity. The DSPM roles themselves add no compute (see the tests).

locals {
  dspm_sql_managed_instance_tde_identity_name = "upwind-cs-sqlmi-scan-identity-${var.upwind_organization_id}"

  # De-duplicated case-insensitively, keyed by the lower-cased ID, keeping the
  # first spelling given (as for dspm_sql_managed_instances).
  dspm_sql_managed_instance_tde_key_vaults = local.dspm_sql_managed_instance_enabled ? {
    for key, spellings in { for id in var.dspm_sql_tde_key_vault_ids : lower(id) => id... } : key => spellings[0]
  } : {}
  dspm_sql_managed_instance_tde_enabled = length(local.dspm_sql_managed_instance_tde_key_vaults) > 0
}

resource "azurerm_user_assigned_identity" "dspm_sql_managed_instance_tde" {
  count               = local.dspm_sql_managed_instance_tde_enabled ? 1 : 0
  name                = local.dspm_sql_managed_instance_tde_identity_name
  resource_group_name = azurerm_resource_group.dspm_sql_managed_instance[0].name
  # The RG ignores changes to its own location, so this follows the RG's
  # actual location, and scan instances in any region can use the identity.
  location = azurerm_resource_group.dspm_sql_managed_instance[0].location
  tags     = var.tags
}

resource "azurerm_role_assignment" "dspm_sql_managed_instance_tde_key_vault" {
  for_each             = local.dspm_sql_managed_instance_tde_key_vaults
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.dspm_sql_managed_instance_tde[0].principal_id
  # A new identity may not have replicated in Entra yet: with the type given,
  # ARM doesn't look the principal up.
  principal_type = "ServicePrincipal"
  scope          = each.value
}

# endregion

# endregion
