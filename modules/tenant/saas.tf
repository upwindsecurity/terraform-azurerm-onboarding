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
# The worker creates each snapshot in the target disk's own subscription/RG, so
# the Snapshot SP is granted tenant-wide write for first delivery. Narrowing the
# write grant to a least-privilege boundary is a tracked follow-up.

locals {
  # --- Snapshot SP (mirrors the outpost worker identity) ---

  # SaaS-specific built-in roles: snapshot CRUD + cross-subscription disk read.
  # The custom CloudScannerTargetRole is granted separately below.
  saas_snapshot_roles = ["Reader", "Disk Snapshot Contributor", "Data Operator for Managed Disks"]

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

  # Snapshot SP worker data-plane roles. These back DSPM (blob/file content read), so
  # they are gated on DSPM being enabled (local.dspm_enabled) in addition to saas_enabled.
  saas_snapshot_worker_role_assignments = (var.saas_enabled && local.dspm_enabled) ? {
    for pair in setproduct(local.normalized_management_group_ids, local.saas_snapshot_worker_roles) :
    "${pair[0]}|${pair[1]}" => { scope = pair[0], role = pair[1] }
  } : {}

  # DSPM marker role scopes - minted only when DSPM is enabled, alongside the worker
  # data-plane grant above, so "marker exists <=> DSPM provisioned" holds.
  saas_dspm_marker_scopes = (var.saas_enabled && local.dspm_enabled) ? toset(local.normalized_management_group_ids) : []

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

# Snapshot SP -> Reader + Disk Snapshot Contributor + Data Operator at MG scope.
resource "azurerm_role_assignment" "saas_snapshot" {
  for_each = local.saas_snapshot_role_assignments

  principal_id         = local.saas_snapshot_sp_object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
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

# --- DSPM feature-gate marker ---
#
# CloudScanner's DSPM feature gate needs a Graph-free way to tell that DSPM (data-plane
# blob read) was provisioned for a SaaS org. It can't key off the built-in Storage Blob
# Data Reader assignment above: that only carries a bare principal GUID, and resolving it
# to "our" Snapshot SP would require the service-principal inventory, which is only
# collected if the customer granted Microsoft Graph access (not guaranteed).
#
# So we mint a deterministically-named custom role DEFINITION per MG scope, alongside the
# data-plane grant (same saas_target_role_scopes / saas_enabled gating). It carries only a
# benign management-plane read (no data_actions) so - unlike the built-in data readers - it
# can be created at management-group scope. Role definitions are collected via
# management-plane reads, so the gate detects it with no Graph dependency via
# SearchAzureRoleDefinitions(roleName like "UpwindDSPMEnabled-{orgID}%").
#
# The "UpwindDSPMEnabled" name prefix is a contract with cloudscanner
# cloudproviders.DSPMRolePrefix and the serverless saas-mg-roles.bicep dspmMarkerRole - a
# rename must move on all three sides together.
resource "azurerm_role_definition" "saas_dspm_marker" {
  for_each    = local.saas_dspm_marker_scopes
  name        = "UpwindDSPMEnabled-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Marker role signalling that Upwind DSPM (data-plane blob read) is provisioned for this org; detected by the CloudScanner DSPM feature gate."
  scope       = each.value
  permissions {
    actions     = ["Microsoft.Storage/storageAccounts/read"]
    not_actions = []
  }
}

# Wait for the marker role definitions to propagate before assigning them.
resource "time_sleep" "saas_dspm_marker_wait" {
  count           = (var.saas_enabled && local.dspm_enabled) ? 1 : 0
  depends_on      = [azurerm_role_definition.saas_dspm_marker]
  create_duration = var.azure_role_definition_wait_time
}

# Snapshot SP -> DSPM marker role at each MG scope. Assigning (not just defining) keeps the
# role from reading as orphaned to cleanup tooling; the Snapshot SP already holds Reader, so
# this grants zero additional access.
resource "azurerm_role_assignment" "saas_dspm_marker" {
  for_each = azurerm_role_definition.saas_dspm_marker

  role_definition_id = each.value.role_definition_resource_id
  principal_id       = local.saas_snapshot_sp_object_id
  scope              = each.value.scope
  depends_on         = [time_sleep.saas_dspm_marker_wait[0]]
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

# Fetcher SP -> custom role at each MG scope.
resource "azurerm_role_assignment" "saas_fetcher_custom_role" {
  for_each = azurerm_role_definition.saas_fetcher_custom_role

  role_definition_id = each.value.role_definition_resource_id
  principal_id       = local.saas_fetcher_sp_object_id
  scope              = each.value.scope
}

# endregion

# endregion saas
