mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_data "azuread_application_published_app_ids" {
    defaults = {
      result = { MicrosoftGraph = "00000003-0000-0000-c000-000000000000" }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"access_token\":\"test-token\"}"
    }
  }
}

# The cloud-credentials listing is decoded as a JSON array.
override_data {
  target = data.http.upwind_get_cloud_credentials_request
  values = {
    status_code   = 200
    response_body = "[]"
  }
}

variables {
  upwind_organization_id = "org_test"
  upwind_client_id       = "client"
  upwind_client_secret   = "secret"

  azure_application_msgraph_roles = []
}

run "us_uses_base_endpoints" {
  command = plan
  variables { upwind_region = "us" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "rejects_bad_pdc_format" {
  command = plan
  variables { upwind_region = "pdc1" }
  expect_failures = [var.upwind_region]
}

run "rejects_unknown_region" {
  command = plan
  variables { upwind_region = "xx" }
  expect_failures = [var.upwind_region]
}

run "eu_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "eu" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.eu.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.eu.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.eu.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "me_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "me" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.me.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.me.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.me.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "ap_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "ap" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.ap.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.ap.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.ap.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "pdc01_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "pdc01" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.pdc01.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.pdc01.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.pdc01.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "pdc02_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "pdc02" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.pdc02.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.pdc02.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.pdc02.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}

run "pdc07_region_inserted_into_endpoints" {
  command = plan
  variables { upwind_region = "pdc07" }

  assert {
    condition     = data.http.upwind_get_access_token_request.url == "https://auth.pdc07.upwind.io/oauth/token"
    error_message = "unexpected auth URL"
  }
  assert {
    condition     = strcontains(data.http.upwind_get_access_token_request.request_body, "audience=https://integration.pdc07.upwind.io&")
    error_message = "unexpected audience"
  }
  assert {
    condition     = data.http.upwind_get_cloud_credentials_request.url == "https://integration.pdc07.upwind.io/v1/organizations/org_test/cloud-credentials"
    error_message = "unexpected integration URL"
  }
}
