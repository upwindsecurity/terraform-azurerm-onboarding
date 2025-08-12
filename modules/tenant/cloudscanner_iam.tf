# region Deployer

locals {
  resource_suffix = format("%s%s", var.upwind_organization_id, var.resource_suffix)
}

resource "azurerm_role_definition" "deployer" {
  count       = local.cloudscanner_enabled ? 1 : 0
  name        = "CloudScannerDeploymentRole-${local.resource_suffix}"
  description = "Role for CloudScanner deployment to create and manage resources in this subscription"
  scope       = local.orchestrator_subscription_scope
  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",
      "Microsoft.Resources/deployments/*",
      "Microsoft.KeyVault/vaults/*",
      "Microsoft.Compute/*",
      "Microsoft.Network/*",
      "Microsoft.Storage/*",
      "Microsoft.OperationalInsights/*",
      "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",
      "Microsoft.App/*",
      # Need these for SSH key generation
      "Microsoft.Resources/deploymentScripts/*",
      "Microsoft.ContainerInstance/containerGroups/*"
    ]
  }
}

# Wait for the deployer role definition to be created
resource "time_sleep" "deployer_role_definition_wait" {
  count           = local.cloudscanner_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.deployer]
  create_duration = var.azure_role_definition_wait_time
}

# role assignment for our AD application's service principal
resource "azurerm_role_assignment" "deployer" {
  count              = local.cloudscanner_enabled ? 1 : 0
  role_definition_id = azurerm_role_definition.deployer[0].role_definition_resource_id
  principal_id       = azuread_service_principal.this.object_id
  scope              = local.orchestrator_subscription_scope
  depends_on         = [time_sleep.deployer_role_definition_wait[0]]
}

# endregion

# region Worker

resource "azurerm_user_assigned_identity" "worker_user_assigned_identity" {
  count               = local.cloudscanner_enabled ? 1 : 0
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = azurerm_resource_group.orgwide_resource_group[0].location
  name                = "upwind-cs-vmss-identity-${var.upwind_organization_id}"
}

resource "azurerm_role_definition" "cloudscanner_worker" {
  count       = local.cloudscanner_enabled ? 1 : 0
  name        = "CloudScannerWorkerRole-${local.resource_suffix}"
  description = "Role for CloudScanner workers to manage cloudscanner resources in this subscription"
  scope       = local.orchestrator_subscription_scope
  permissions {
    actions = [
      "Microsoft.Compute/snapshots/read",
      "Microsoft.Compute/snapshots/write",
      "Microsoft.Compute/snapshots/delete",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/delete",
      # Following roles are required for attaching / detaching disks to VMSS instances
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/attachDetachDataDisks/action",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/write",
      "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
  }
}

# Wait for the worker role definition to be created
resource "time_sleep" "cloudscanner_worker_role_definition_wait" {
  count           = local.cloudscanner_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.cloudscanner_worker]
  create_duration = var.azure_role_definition_wait_time
}

# Assigning the worker role to the worker identity subscription wide, we are using the scope of the Cloudscanner subscription.
# The benefit of containing the scope only to worker resource groups is kind of lost since we are assuming deployment privileges subscription wide anyways.
resource "azurerm_role_assignment" "cloudscanner_worker" {
  count              = local.cloudscanner_enabled ? 1 : 0
  role_definition_id = azurerm_role_definition.cloudscanner_worker[0].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope              = local.orchestrator_subscription_scope
  depends_on         = [time_sleep.cloudscanner_worker_role_definition_wait[0]]
}

# Assign Storage Blob Data Reader role to the worker identity in each management group
# Because this is a data action permission, we can't include this in a custom role definition and assign it at a management group scope.
resource "azurerm_role_assignment" "storage_reader" {
  for_each             = local.cloudscanner_enabled ? toset(local.normalized_management_group_ids) : []
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope                = each.value
}

# endregion

# region Scaler

resource "azurerm_user_assigned_identity" "scaler_user_assigned_identity" {
  count               = local.cloudscanner_enabled ? 1 : 0
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = azurerm_resource_group.orgwide_resource_group[0].location
  name                = "upwind-cs-scaler-function-identity-${var.upwind_organization_id}"
}

resource "azurerm_role_definition" "cloudscanner_scaler" {
  count       = local.cloudscanner_enabled ? 1 : 0
  name        = "CloudScannerScalerRole-${local.resource_suffix}"
  description = "Role for CloudScanner scaler to manage cloudscanner resources in this subscription"
  scope       = local.orchestrator_subscription_scope
  permissions {
    actions = [
      # Get scale set details
      "Microsoft.Compute/virtualMachineScaleSets/read",
      # Edit scale set's capacity and machine type
      "Microsoft.Compute/virtualMachineScaleSets/write",
      # Deletes the instances of the Virtual Machine Scale Set
      "Microsoft.Compute/virtualMachineScaleSets/delete/action",
      # Get information on specific instances
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      # Get information on disks
      "Microsoft.Compute/disks/read",
      # Delete disks
      "Microsoft.Compute/disks/delete",
      # Get information on snapshots
      "Microsoft.Compute/snapshots/write",
      # Delete snapshots
      "Microsoft.Compute/snapshots/delete",
    ]
  }
}

# Wait for the scaler role definition to be created
resource "time_sleep" "cloudscanner_scaler_role_definition_wait" {
  count           = local.cloudscanner_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.cloudscanner_scaler]
  create_duration = var.azure_role_definition_wait_time
}

# Assigning the scaler role to the scaler identity subscription wide, we are using the scope of the Cloudscanner subscription.
# The benefit of containing the scope only to worker resource groups is kind of lost since we are assuming deployment privileges subscription wide anyways.
resource "azurerm_role_assignment" "cloudscanner_scaler" {
  count              = local.cloudscanner_enabled ? 1 : 0
  role_definition_id = azurerm_role_definition.cloudscanner_scaler[0].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.scaler_user_assigned_identity[0].principal_id
  scope              = local.orchestrator_subscription_scope
  depends_on         = [time_sleep.cloudscanner_scaler_role_definition_wait[0]]
}

# endregion

# region Key Vault Access

# Create an identity that will have key vault service encryption access subscription wide
resource "azurerm_user_assigned_identity" "key_vault_access" {
  count               = local.cloudscanner_enabled ? 1 : 0
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = azurerm_resource_group.orgwide_resource_group[0].location
  name                = "upwind-cs-disk-encryption-identity-${var.upwind_organization_id}"
}

# Assign the "Key Vault Crypto Service Encryption User" role to the Azure Disk Encryption set
resource "azurerm_role_assignment" "disk_encryption_key_vault_access" {
  count                = local.cloudscanner_enabled ? 1 : 0
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.key_vault_access[0].principal_id
  scope                = local.orchestrator_subscription_scope
}

# endregion

# region Target

# Create target role definitions per management group
resource "azurerm_role_definition" "target_role" {
  for_each    = local.cloudscanner_enabled ? toset(local.normalized_management_group_ids) : []
  name        = "CloudScannerTargetRole-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Role for CloudScanner workers to snapshot virtual machines and pull acr images in this management group"
  scope       = each.value
  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/instanceView/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/diskEncryptionSets/read",
      "Microsoft.Compute/disks/beginGetAccess/action",
      "Microsoft.ContainerRegistry/registries/pull/read",
      "Microsoft.Web/sites/config/list/action"
    ]
  }
}

# Wait for all target role definitions to be created
resource "time_sleep" "target_role_definition_wait" {
  count           = local.cloudscanner_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.target_role]
  create_duration = var.azure_role_definition_wait_time
}

# add role assignments for each target subscription
resource "azurerm_role_assignment" "target_role_assignment" {
  for_each           = resource.azurerm_role_definition.target_role
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope              = each.value.scope
  depends_on         = [time_sleep.target_role_definition_wait[0]]
}

# endregion
