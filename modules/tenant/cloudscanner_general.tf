locals {
  # This variable may be marked as sensitive if the scanner_client_id variable is sourced from a sensitive data source (e.g., Key Vault)
  cloudscanner_enabled_sensitive = var.azure_orchestrator_subscription_id != "" && var.scanner_client_id != ""

  # Remove sensitive marking if present (e.g., from Key Vault data source), otherwise use value as-is
  # This handles both plaintext and sensitive-marked values gracefully
  cloudscanner_enabled = try(nonsensitive(local.cloudscanner_enabled_sensitive), local.cloudscanner_enabled_sensitive)
}

check "scanner_credentials_provided" {
  assert {
    condition     = !local.cloudscanner_enabled || (var.scanner_client_id != null && var.scanner_client_id != "" && var.scanner_client_secret != null && var.scanner_client_secret != "")
    error_message = "When scanner_client_id is provided, scanner_client_secret must also be provided and non-empty."
  }
}

resource "azurerm_resource_group" "orgwide_resource_group" {
  count    = local.cloudscanner_enabled ? 1 : 0
  name     = "upwind-cs-rg-${var.upwind_organization_id}"
  location = var.azure_cloudscanner_location
  tags     = var.tags
}
