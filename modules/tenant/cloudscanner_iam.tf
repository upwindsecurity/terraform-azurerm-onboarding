# region Deployer

locals {
  resource_suffix = format("%s%s", var.upwind_organization_id, var.resource_suffix)

  # Storage Blob/File data readers (self-hosted below and SaaS in saas.tf) back Azure
  # Function code scanning, which is on by default - so they are granted whenever
  # scanning is provisioned, gated only by the legacy disable_function_scanning opt-out.
  function_scanning_enabled = !var.disable_function_scanning

  # DSPM is opt-in via upwind_feature_dspm_enabled (default false) and gates ONLY the
  # DSPM marker role (self-hosted below and SaaS in saas.tf) - the CloudScanner feature
  # gate's signal that DSPM is enabled for this org. DSPM reads data via the same
  # storage grants as function scanning, so the disable_function_scanning opt-out also
  # turns DSPM off.
  dspm_enabled = var.upwind_feature_dspm_enabled && local.function_scanning_enabled

  # Actions granted by CloudScannerTargetRole: target-disk read + begin-access +
  # ACR pull. Shared between the self-hosted (outpost) worker identity and the
  # SaaS Snapshot SP (see saas.tf) so the two paths never drift - mirrors
  # targetRoleActions in the serverless shared-role-config.jsonc.
  cloudscanner_target_role_actions = [
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

  # Determine cloudscanner role assignment scopes based on include/exclude subscription parameters
  # Priority logic:
  # 1. If include list is provided: use only those subscriptions (overrides management groups)
  # 2. If exclude list is provided: expand to subscription-level assignments, excluding specified ones
  #    - This allows combining with management groups by filtering all tenant subscriptions
  # 3. Otherwise: use management group scopes (or tenant root if azure_tenant_id is set)
  cloudscanner_scopes = length(var.cloudscanner_include_subscriptions) > 0 ? [
    for sub_id in var.cloudscanner_include_subscriptions :
    "/subscriptions/${sub_id}"
    ] : (
    length(var.cloudscanner_exclude_subscriptions) > 0 ? [
      for sub in data.azurerm_subscriptions.all.subscriptions :
      "/subscriptions/${sub.subscription_id}"
      if !contains(var.cloudscanner_exclude_subscriptions, sub.subscription_id)
    ] : local.normalized_management_group_ids
  )
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
  principal_id       = local.service_principal_object_id
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
  tags                = var.tags
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
      "Microsoft.Compute/disks/beginGetAccess/action",
      # Required for reencrypting CMK encrypted disks
      "Microsoft.Compute/diskEncryptionSets/read",
      # Following roles are required for attaching / detaching disks to VMSS instances
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/instanceView/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/attachDetachDataDisks/action",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/write",
      # Required for worker VMs to join subnets
      "Microsoft.Network/virtualNetworks/subnets/join/action",
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

# Assign Storage Blob Data Reader role to the worker identity
# Because this is a data action permission, we can't include this in a custom role definition and assign it at a management group scope.
# If function_storage_accounts is provided, assign to specific storage accounts only.
# Otherwise, assign to all resources in cloudscanner scope.
# Not gated on DSPM: function scanning (on by default) reads function code via this grant.
resource "azurerm_role_assignment" "storage_reader" {
  for_each = (local.cloudscanner_enabled && local.function_scanning_enabled) ? (
    length(var.function_storage_accounts) > 0 ?
    toset(var.function_storage_accounts) :
    toset(local.cloudscanner_scopes)
  ) : []
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope                = each.value
}

# Assign Storage File Data Privileged Reader role to the worker identity
# If function_storage_accounts is provided, assign to specific storage accounts only.
# Otherwise, assign to all resources in cloudscanner scope.
# Not gated on DSPM: function scanning (on by default) reads function code via this grant.
resource "azurerm_role_assignment" "storage_file_reader" {
  for_each = (local.cloudscanner_enabled && local.function_scanning_enabled) ? (
    length(var.function_storage_accounts) > 0 ?
    toset(var.function_storage_accounts) :
    toset(local.cloudscanner_scopes)
  ) : []

  role_definition_name = "Storage File Data Privileged Reader"
  principal_id         = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope                = each.value
}

# Assign a least-privilege App Service SCM bearer role to the worker identity
resource "azurerm_role_definition" "app_service_scm_bearer_reader" {
  for_each = (local.cloudscanner_enabled && local.function_scanning_enabled) ? toset(local.cloudscanner_scopes) : []

  name        = "CloudScannerAppServiceScmRole-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Role for CloudScanner workers to read App Service metadata and access SCM with bearer authentication in this scope"
  scope       = each.value

  permissions {
    actions = [
      "Microsoft.Web/sites/read",
      "Microsoft.Web/sites/publish/Action"
    ]
  }
}

resource "time_sleep" "app_service_scm_bearer_reader_role_definition_wait" {
  count           = (local.cloudscanner_enabled && local.function_scanning_enabled) ? 1 : 0
  depends_on      = [azurerm_role_definition.app_service_scm_bearer_reader]
  create_duration = var.azure_role_definition_wait_time
}

resource "azurerm_role_assignment" "app_service_scm_bearer_reader" {
  for_each           = resource.azurerm_role_definition.app_service_scm_bearer_reader
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope              = each.value.scope
  depends_on         = [time_sleep.app_service_scm_bearer_reader_role_definition_wait[0]]
}

# endregion

# region Scaler

resource "azurerm_user_assigned_identity" "scaler_user_assigned_identity" {
  count               = local.cloudscanner_enabled ? 1 : 0
  resource_group_name = azurerm_resource_group.orgwide_resource_group[0].name
  location            = azurerm_resource_group.orgwide_resource_group[0].location
  name                = "upwind-cs-scaler-function-identity-${var.upwind_organization_id}"
  tags                = var.tags
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
  tags                = var.tags
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

# Create target role definition per scope
resource "azurerm_role_definition" "target_role" {
  for_each    = local.cloudscanner_enabled ? toset(local.cloudscanner_scopes) : []
  name        = "CloudScannerTargetRole-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Role for CloudScanner workers to snapshot virtual machines and pull acr images in this scope"
  scope       = each.value
  permissions {
    actions = local.cloudscanner_target_role_actions
  }
}

# Wait for target role definitions to be created
resource "time_sleep" "target_role_definition_wait" {
  count           = local.cloudscanner_enabled ? 1 : 0
  depends_on      = [azurerm_role_definition.target_role]
  create_duration = var.azure_role_definition_wait_time
}

# Add role assignments for each target scope using the matching role definition
resource "azurerm_role_assignment" "target_role_assignment" {
  for_each           = resource.azurerm_role_definition.target_role
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope              = each.value.scope
  depends_on         = [time_sleep.target_role_definition_wait[0]]
}

# endregion

# region DSPM marker

# DSPM feature-gate marker role, minted per scope only when DSPM is opted in
# (upwind_feature_dspm_enabled). Gives CloudScanner's DSPM feature gate a Graph-free
# signal that DSPM is enabled for this org: the role carries only a benign
# management-plane read (no dataActions), and role definitions are collected via
# management-plane reads, so the gate detects it via
# SearchAzureRoleDefinitions(roleName like "UpwindDSPMEnabled-{orgID}%").
#
# The "UpwindDSPMEnabled" name prefix is a contract with cloudscanner
# cloudproviders.DSPMRolePrefix, the saas.tf saas_dspm_marker role and the serverless
# mg-roles/sub-roles/saas-mg-roles.bicep dspmMarkerRole - a rename must move on all
# sides together. In SaaS mode cloudscanner_enabled is always false (see
# cloudscanner_general.tf), so this never overlaps the identically named marker
# saas.tf mints there.
resource "azurerm_role_definition" "dspm_marker" {
  for_each    = (local.cloudscanner_enabled && local.dspm_enabled) ? toset(local.cloudscanner_scopes) : []
  name        = "UpwindDSPMEnabled-${local.resource_suffix}-${split("/", each.value)[length(split("/", each.value)) - 1]}"
  description = "Marker role signalling that Upwind DSPM is enabled for this org; detected by the CloudScanner DSPM feature gate."
  scope       = each.value
  permissions {
    actions = ["Microsoft.Storage/storageAccounts/read"]
  }
}

resource "time_sleep" "dspm_marker_wait" {
  count           = (local.cloudscanner_enabled && local.dspm_enabled) ? 1 : 0
  depends_on      = [azurerm_role_definition.dspm_marker]
  create_duration = var.azure_role_definition_wait_time
}

# Worker identity -> DSPM marker role at each scope. Assigning (not just defining) keeps
# the marker from reading as orphaned to cleanup tooling. The role carries only
# management-plane storage-account metadata read (no dataActions); note that when
# function_storage_accounts narrows the data readers to specific accounts, this still
# lets the worker ENUMERATE storage accounts across the scope (metadata only, no data).
resource "azurerm_role_assignment" "dspm_marker" {
  for_each           = azurerm_role_definition.dspm_marker
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker_user_assigned_identity[0].principal_id
  scope              = each.value.scope
  depends_on         = [time_sleep.dspm_marker_wait[0]]
}

# endregion
