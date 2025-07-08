locals {
  upwind_access_token         = try(jsondecode(data.http.upwind_get_access_token_request.response_body).access_token, null)
  upwind_auth_endpoint        = var.upwind_region == "us" ? var.upwind_auth_endpoint : replace(var.upwind_auth_endpoint, ".upwind.", ".eu.upwind.")
  upwind_integration_endpoint = var.upwind_region == "us" ? var.upwind_integration_endpoint : replace(var.upwind_integration_endpoint, ".upwind.", ".eu.upwind.")
}

data "http" "upwind_get_access_token_request" {
  method = "POST"

  url = format(
    "%s/oauth/token",
    local.upwind_auth_endpoint,
  )

  request_headers = {
    "Content-Type" = "application/x-www-form-urlencoded"
  }

  request_body = join("&", [
    "grant_type=client_credentials",
    "audience=${local.upwind_integration_endpoint}",
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
  }
}
