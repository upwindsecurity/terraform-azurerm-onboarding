locals {
  # Generate key vault name with a hash of the org ID to avoid collisions
  # sha1() gives us 40 chars, we only take the first 14 to make it an even 24 characters - max allowed
  # Not using the resource suffix here, we've a better chance of global uniqueness with this approach.
  # Max length is 24, prefix 3 + suffix 10 + hash 11
  key_vault_name = "kv-${substr(sha1(var.upwind_organization_id), 0, 11)}${var.resource_suffix}"
}

# Create Azure Key Vault for organization-wide secrets
# No purge protection because we can just set up new secrets no bother.
resource "azurerm_key_vault" "orgwide_key_vault" {
  count                     = local.cloudscanner_enabled ? 1 : 0
  name                      = local.key_vault_name
  location                  = azurerm_resource_group.orgwide_resource_group[0].location
  resource_group_name       = azurerm_resource_group.orgwide_resource_group[0].name
  tenant_id                 = data.azurerm_subscription.orchestrator.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  tags = merge(var.tags, {
    "UpwindComponent" = "CloudScanner"
    "UpwindOrgId"     = var.upwind_organization_id
  })
}

resource "azurerm_role_assignment" "kv_admin" {
  count                = local.cloudscanner_enabled ? 1 : 0
  scope                = azurerm_key_vault.orgwide_key_vault[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_secrets_worker" {
  count                = local.cloudscanner_enabled ? 1 : 0
  scope                = azurerm_key_vault.orgwide_key_vault[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
}

resource "azurerm_role_assignment" "kv_secrets_scaler" {
  count                = local.cloudscanner_enabled ? 1 : 0
  scope                = azurerm_key_vault.orgwide_key_vault[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.scaler_user_assigned_identity[0].principal_id
}

# Add organization-wide secrets to Key Vault
resource "azurerm_key_vault_secret" "scanner_client_id" {
  count        = local.cloudscanner_enabled ? 1 : 0
  name         = "upwind-client-id"
  value        = var.scanner_client_id
  key_vault_id = azurerm_key_vault.orgwide_key_vault[0].id
  depends_on   = [azurerm_role_assignment.kv_admin]
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "scanner_client_secret" {
  count        = local.cloudscanner_enabled ? 1 : 0
  name         = "upwind-client-secret"
  value        = var.scanner_client_secret
  key_vault_id = azurerm_key_vault.orgwide_key_vault[0].id
  depends_on   = [azurerm_role_assignment.kv_admin]
  tags         = var.tags
}
