locals {
  upwind_access_token = sensitive(
    try(
      jsondecode(
        data.http.upwind_get_access_token_request[0].response_body
      ).access_token,
      null
    )
  )
  upwind_auth_endpoint        = var.upwind_region == "us" ? var.upwind_auth_endpoint : replace(var.upwind_auth_endpoint, ".upwind.", format(".%s.upwind.", var.upwind_region))
  upwind_integration_endpoint = var.upwind_region == "us" ? var.upwind_integration_endpoint : replace(var.upwind_integration_endpoint, ".upwind.", format(".%s.upwind.", var.upwind_region))
}

# Skipped in SaaS mode (var.saas_enabled): SaaS onboarding is secretless and
# makes no Upwind API call, so no access token is needed.
data "http" "upwind_get_access_token_request" {
  count = var.saas_enabled ? 0 : 1

  method = "POST"

  url = format(
    "%s/oauth/token",
    local.upwind_auth_endpoint
  )

  request_headers = {
    "Content-Type" = "application/x-www-form-urlencoded"
  }

  request_body = join("&", [
    "grant_type=client_credentials",
    format("audience=%s", local.upwind_integration_endpoint),
    "client_id=${var.upwind_client_id}",
    "client_secret=${var.upwind_client_secret}",
  ])

  retry {
    attempts = 3
  }

  lifecycle {
    precondition {
      condition     = var.upwind_client_id != null && var.upwind_client_secret != null
      error_message = "Invalid client credentials. Please verify your client ID and client secret."
    }
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to obtain access token from ${local.upwind_auth_endpoint} (status ${self.status_code}). Response: ${self.response_body}."
    }
  }
}
