locals {
  cloudscanner_enabled            = var.azure_orchestrator_subscription_id != "" && var.scanner_client_id != ""
  orchestrator_subscription_scope = "/subscriptions/${var.azure_orchestrator_subscription_id}"
}

# Register the Microsoft.App resource provider which is required for Container Apps
# Using null_resource with local-exec to avoid provider configuration issues when used as a module
# If key_vault_deny_traffic is true, we don't need to register the Microsoft.App provider. The scaler will run in Upwind.
resource "null_resource" "register_app_service_provider" {
  count = local.cloudscanner_enabled && !var.skip_app_service_provider_registration && !var.key_vault_deny_traffic ? 1 : 0

  provisioner "local-exec" {
    command     = <<EOT
      echo "Registering Microsoft.App provider in subscription ${var.azure_orchestrator_subscription_id}..."
      az provider register --namespace Microsoft.App --subscription ${var.azure_orchestrator_subscription_id}

      echo "Waiting for Microsoft.App provider registration to complete..."
      MAX_ATTEMPTS=60  # 10 minutes maximum wait time
      ATTEMPT=0

      while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        STATE=$(az provider show --namespace Microsoft.App --subscription ${var.azure_orchestrator_subscription_id} --query "registrationState" --output tsv 2>/dev/null)

        # Check if az command failed
        if [ $? -ne 0 ]; then
          echo "Error: Failed to query provider registration state. Attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS"
          ATTEMPT=$((ATTEMPT + 1))
          sleep 10
          continue
        fi

        # Trim whitespace and convert to lowercase for comparison
        STATE_CLEAN=$(echo "$STATE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        echo "Current registration state: $STATE"

        # Check for registered state (case-insensitive, whitespace-trimmed)
        if [ "$STATE_CLEAN" = "registered" ]; then
          echo "Microsoft.App provider successfully registered!"
          break
        fi

        # Check for failed states
        if [ "$STATE_CLEAN" = "registrationfailed" ] || [ "$STATE_CLEAN" = "unregistered" ]; then
          echo "Error: Provider registration failed with state: $STATE"
          exit 1
        fi

        ATTEMPT=$((ATTEMPT + 1))
        echo "Registration still in progress. Attempt $ATTEMPT/$MAX_ATTEMPTS. Waiting 10 seconds..."
        sleep 10
      done

      # Final check - if we've exhausted all attempts
      if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "Error: Provider registration timed out after $((MAX_ATTEMPTS * 10)) seconds"
        echo "Final state was: $STATE"
        exit 1
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "azurerm_resource_group" "orgwide_resource_group" {
  count    = local.cloudscanner_enabled ? 1 : 0
  name     = "upwind-cs-rg-${var.upwind_organization_id}"
  location = var.azure_cloudscanner_location
  tags     = var.tags
}
