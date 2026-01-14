locals {
  cloudscanner_enabled_sensitive = var.azure_orchestrator_subscription_id != "" && var.scanner_client_id != ""

  # Force remove any sensitive marking - this is safe because the result is just a boolean
  cloudscanner_enabled = nonsensitive(local.cloudscanner_enabled_sensitive)
}

resource "azurerm_resource_group" "orgwide_resource_group" {
  count    = local.cloudscanner_enabled ? 1 : 0
  name     = "upwind-cs-rg-${var.upwind_organization_id}"
  location = var.azure_cloudscanner_location
  tags     = var.tags
}
