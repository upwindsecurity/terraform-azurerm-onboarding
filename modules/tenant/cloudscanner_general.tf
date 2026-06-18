locals {
  # This variable may be marked as sensitive if the scanner_client_id variable is sourced from a sensitive data source (e.g., Key Vault)
  cloudscanner_enabled_sensitive = var.azure_orchestrator_subscription_id != "" && var.scanner_client_id != ""

  # Remove sensitive marking if present (e.g., from Key Vault data source), otherwise use value as-is
  # This handles both plaintext and sensitive-marked values gracefully
  cloudscanner_enabled = try(nonsensitive(local.cloudscanner_enabled_sensitive), local.cloudscanner_enabled_sensitive)
}

resource "azurerm_resource_group" "orgwide_resource_group" {
  count    = local.cloudscanner_enabled ? 1 : 0
  name     = "upwind-cs-rg-${var.upwind_organization_id}"
  location = var.azure_cloudscanner_location
  # The UpwindManagedCloudScanners tag is only set when the customer is
  # self-managing CloudScanner. onboarding-service treats absent as
  # Upwind-managed (the default), mirroring the AWS ManagedCloudScannersTag
  # pattern. Keeping the default-mode RG tag-free avoids a needless diff
  # against existing deployments and makes self-managed mode visually obvious.
  tags = merge(
    var.tags,
    var.self_managed_cloudscanner ? {
      "UpwindManagedCloudScanners" = "Disabled"
    } : {},
  )
}
