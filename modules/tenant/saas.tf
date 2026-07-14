# region SaaS (provider-hosted, secretless) onboarding
#
# In SaaS mode (var.saas_enabled) the customer tenant holds no secrets, managed
# identities, or compute. The customer consents to Upwind's two multi-tenant app
# registrations (Snapshot + Fetcher); this materializes their service principals
# in the customer tenant, which are then granted scoped ARM roles at the
# tenant-root management group - inherited by every subscription, current and
# future. The self-hosted resources (app registration, CSPM role assignments,
# Key Vault, managed identities, custom roles, credential submission) are gated
# off when saas_enabled is true.
#
# The role sets mirror the self-hosted (outpost) principals so the two paths stay
# in lock-step - the same source of truth (var.azure_roles / var.azure_custom_role_permissions)
# feeds both. Application translation (from the outpost path / mg-roles.bicep):
#   service principal (app registration) -> Fetcher SP  (read-level inventory)
#   worker identity                      -> Snapshot SP (snapshotting)
#
# Snapshot write/delete is NOT granted tenant-wide. Only non-destructive roles are
# assigned at the management group (Reader, read-only CloudScannerTargetRole, worker
# storage readers, and the Fetcher's read roles). The Snapshot SP's snapshot
# write/delete (Disk Snapshot Contributor + Data Operator) is confined to a single
# central snapshots resource group created in the orchestrator subscription. The
# worker creates each snapshot in that RG, sourcing the customer disk it reads via
# the MG-wide read grant.

locals {
  # --- Snapshot SP (mirrors the outpost worker identity) ---

  # Broad, read-only built-in role at MG scope. Snapshot write/delete is NOT here -
  # it is confined to the central snapshots RG (see saas_snapshot_write_roles below).
  saas_snapshot_roles = ["Reader"]

  # Snapshot write/delete roles, assigned ONLY on the central snapshots RG in the
  # orchestrator subscription (never tenant-wide).
  saas_snapshot_write_roles = ["Disk Snapshot Contributor", "Data Operator for Managed Disks"]

  # Central snapshots RG name (orchestrator subscription). Convention: upwind-cs-rg-<orgId>.
  saas_snapshot_resource_group_name = var.customer_snapshot_resource_group != "" ? var.customer_snapshot_resource_group : "upwind-cs-rg-${var.upwind_organization_id}"

  # Worker data-plane read roles - mirrors the outpost storage_reader /
  # storage_file_reader assignments (bicep workerBuiltinRoles). Assigned at MG
  # scope so the Snapshot SP can read across every subscription in the tenant.
  saas_snapshot_worker_roles = ["Storage Blob Data Reader", "Storage File Data Privileged Reader"]

  # --- SP materialization ---

  # Create the SP only when an existing object ID was not supplied. When the
  # customer pre-creates the SP out-of-band (e.g. admin consent), they pass its
  # object ID and the module skips creation (no Graph permissions needed) - it
  # only assigns the ARM roles.
  create_saas_snapshot_sp = var.saas_enabled && var.snapshot_app_service_principal_object_id == ""
  create_saas_fetcher_sp  = var.saas_enabled && var.fetcher_app_service_principal_object_id == ""

  # Effective SP object IDs: the supplied one, otherwise the created resource's.
  saas_snapshot_sp_object_id = var.snapshot_app_service_principal_object_id != "" ? var.snapshot_app_service_principal_object_id : one(azuread_service_principal.saas_snapshot[*].object_id)
  saas_fetcher_sp_object_id  = var.fetcher_app_service_principal_object_id != "" ? var.fetcher_app_service_principal_object_id : one(azuread_service_principal.saas_fetcher[*].object_id)

  # --- Assignment maps (keyed by "scope|role" across the MG scope(s)) ---

  # Snapshot SP built-in roles.
  saas_snapshot_role_assignments = var.saas_enabled ? {
    for pair in setproduct(local.normalized_management_group_ids, local.saas_snapshot_roles) :
    "${pair[0]}|${pair[1]}" => { scope = pair[0], role = pair[1] }
  } : {}

  # Snapshot SP worker data-plane roles.
  saas_snapshot_worker_role_assignments = var.saas_enabled ? {
    for pair in setproduct(local.normalized_management_group_ids, local.saas_snapshot_worker_roles) :
    "${pair[0]}|${pair[1]}" => { scope = pair[0], role = pair[1] }
  } : {}

  # Snapshot SP write/delete roles, keyed by role - scoped to the central RG only.
  saas_snapshot_write_role_assignments = var.saas_enabled ? { for role in local.saas_snapshot_write_roles : role => role } : {}

  # Snapshot SP CloudScannerTargetRole scopes (target-disk read + begin-access +
  # ACR pull - identical actions to the outpost worker's target role).
  saas_target_role_scopes = var.saas_enabled ? toset(local.normalized_management_group_ids) : []

  # --- Fetcher SP (mirrors the outpost app-registration SP) ---

  # Fetcher SP built-in read roles (var.azure_roles - same list the outpost app
  # registration gets; bicep builtinRoles).
  saas_fetcher_role_assignments = var.saas_enabled ? {
    for pair in setproduct(local.normalized_management_group_ids, var.azure_roles) :
    "${pair[0]}|${pair[1]}" => { scope = pair[0], role = pair[1] }
  } : {}

  # Fetcher SP custom-role scopes (var.azure_custom_role_permissions - same custom
  # role the outpost app registration gets; bicep customRole).
  saas_fetcher_custom_role_scopes = (var.saas_enabled && length(var.azure_custom_role_permissions) > 0) ? toset(local.normalized_management_group_ids) : []
}

# Materialize the consented service principal for Upwind's Snapshot app reg
# (skipped when snapshot_app_service_principal_object_id is supplied).
resource "azuread_service_principal" "saas_snapshot" {
  count        = local.create_saas_snapshot_sp ? 1 : 0
  client_id    = var.snapshot_app_client_id
  use_existing = true

  lifecycle {
    precondition {
      condition     = var.snapshot_app_client_id != ""
      error_message = "saas_enabled requires snapshot_app_client_id (to create the SP) or snapshot_app_service_principal_object_id (to use an existing one)."
    }
  }
}

# Materialize the consented service principal for Upwind's Fetcher app reg
# (skipped when fetcher_app_service_principal_object_id is supplied).
resource "azuread_service_principal" "saas_fetcher" {
  count        = local.create_saas_fetcher_sp ? 1 : 0
  client_id    = var.fetcher_app_client_id
  use_existing = true

  lifecycle {
    precondition {
      condition     = var.fetcher_app_client_id != ""
      error_message = "saas_enabled requires fetcher_app_client_id (to create the SP) or fetcher_app_service_principal_object_id (to use an existing one)."
    }
  }
}

# region Snapshot SP roles

# Snapshot SP -> Reader (read-only) at MG scope.
resource "azurerm_role_assignment" "saas_snapshot" {
  for_each = local.saas_snapshot_role_assignments

  principal_id         = local.saas_snapshot_sp_object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# Central snapshots resource group in the orchestrator subscription (the azurerm
# provider's subscription). The only scope with snapshot write/delete. On destroy
# this RG - and every snapshot the worker created in it - is removed.
resource "azurerm_resource_group" "saas_snapshots" {
  count    = var.saas_enabled ? 1 : 0
  name     = local.saas_snapshot_resource_group_name
  location = var.azure_cloudscanner_location
  tags     = var.tags
}

# Snapshot SP -> Disk Snapshot Contributor + Data Operator, scoped to the central
# snapshots RG only (never tenant-wide). This is the sole destructive grant.
resource "azurerm_role_assignment" "saas_snapshot_write" {
  for_each = local.saas_snapshot_write_role_assignments

  principal_id         = local.saas_snapshot_sp_object_id
  role_definition_name = each.value
  scope                = azurerm_resource_group.saas_snapshots[0].id
}

# Snapshot SP -> Storage Blob / File data-plane readers at MG scope
# (mirrors the outpost worker's storage_reader / storage_file_reader).
resource "azurerm_role_assignment" "saas_snapshot_worker" {
  for_each = local.saas_snapshot_worker_role_assignments

  principal_id         = local.saas_snapshot_sp_object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# CloudScannerTargetRole custom role definition per MG scope (identical actions
# to the outpost worker's target role - local.cloudscanner_target_role_actions).
resource "azurerm_role_definition" "saas_snapshot_target_role" {
  for_each    = local.saas_target_role_scopes
  name        = "CloudScannerTargetRole-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Role for CloudScanner workers to snapshot virtual machines and pull acr images in this scope"
  scope       = each.value
  permissions {
    actions = local.cloudscanner_target_role_actions
  }
}

# Wait for the target role definitions to propagate before assigning them.
resource "time_sleep" "saas_snapshot_target_role_wait" {
  count           = var.saas_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.saas_snapshot_target_role]
  create_duration = var.azure_role_definition_wait_time
}

# Snapshot SP -> CloudScannerTargetRole at each MG scope.
resource "azurerm_role_assignment" "saas_snapshot_target_role" {
  for_each = azurerm_role_definition.saas_snapshot_target_role

  role_definition_id = each.value.role_definition_resource_id
  principal_id       = local.saas_snapshot_sp_object_id
  scope              = each.value.scope
  depends_on         = [time_sleep.saas_snapshot_target_role_wait[0]]
}

# endregion

# region Fetcher SP roles

# Fetcher SP -> built-in read roles (var.azure_roles) at each MG scope.
resource "azurerm_role_assignment" "saas_fetcher" {
  for_each = local.saas_fetcher_role_assignments

  principal_id         = local.saas_fetcher_sp_object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# Fetcher custom role definition per MG scope (var.azure_custom_role_permissions -
# same actions the outpost app registration's custom role gets).
resource "azurerm_role_definition" "saas_fetcher_custom_role" {
  for_each    = local.saas_fetcher_custom_role_scopes
  name        = "UpwindCustomRole-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Custom role for the Upwind CloudScanner Fetcher service principal in this scope"
  scope       = each.value
  permissions {
    actions     = var.azure_custom_role_permissions
    not_actions = []
  }
}

# Wait for the custom role definitions to propagate before assigning them.
resource "time_sleep" "saas_fetcher_custom_role_wait" {
  count           = var.saas_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.saas_fetcher_custom_role]
  create_duration = var.azure_role_definition_wait_time
}

# Fetcher SP -> custom role at each MG scope.
resource "azurerm_role_assignment" "saas_fetcher_custom_role" {
  for_each = azurerm_role_definition.saas_fetcher_custom_role

  role_definition_id = each.value.role_definition_resource_id
  principal_id       = local.saas_fetcher_sp_object_id
  scope              = each.value.scope
  depends_on         = [time_sleep.saas_fetcher_custom_role_wait[0]]
}

# endregion

# endregion saas
