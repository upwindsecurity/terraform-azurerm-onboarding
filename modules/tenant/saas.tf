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
# The worker creates each snapshot in the target disk's own subscription/RG, so
# the Snapshot SP is granted tenant-wide write for first delivery. Narrowing the
# write grant to a least-privilege boundary is a tracked follow-up.

locals {
  # Built-in roles for the Snapshot SP (snapshot CRUD + cross-subscription disk read).
  saas_snapshot_roles = ["Reader", "Disk Snapshot Contributor", "Data Operator for Managed Disks"]

  # Snapshot role assignments keyed by "scope|role" across the MG scope(s).
  saas_snapshot_role_assignments = var.saas_enabled ? {
    for pair in setproduct(local.normalized_management_group_ids, local.saas_snapshot_roles) :
    "${pair[0]}|${pair[1]}" => { scope = pair[0], role = pair[1] }
  } : {}

  # Fetcher gets Reader at each MG scope.
  saas_fetcher_scopes = var.saas_enabled ? toset(local.normalized_management_group_ids) : []
}

# Materialize the consented service principal for Upwind's Snapshot app reg.
resource "azuread_service_principal" "saas_snapshot" {
  count        = var.saas_enabled ? 1 : 0
  client_id    = var.snapshot_app_client_id
  use_existing = true

  lifecycle {
    precondition {
      condition     = var.snapshot_app_client_id != "" && var.fetcher_app_client_id != ""
      error_message = "saas_enabled requires both snapshot_app_client_id and fetcher_app_client_id."
    }
  }
}

# Materialize the consented service principal for Upwind's Fetcher app reg.
resource "azuread_service_principal" "saas_fetcher" {
  count        = var.saas_enabled ? 1 : 0
  client_id    = var.fetcher_app_client_id
  use_existing = true
}

# Snapshot SP -> Reader + Disk Snapshot Contributor + Data Operator at MG scope.
resource "azurerm_role_assignment" "saas_snapshot" {
  for_each = local.saas_snapshot_role_assignments

  principal_id         = azuread_service_principal.saas_snapshot[0].object_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

# Fetcher SP -> Reader at MG scope.
resource "azurerm_role_assignment" "saas_fetcher" {
  for_each = local.saas_fetcher_scopes

  principal_id         = azuread_service_principal.saas_fetcher[0].object_id
  role_definition_name = "Reader"
  scope                = each.value
}

# endregion saas
