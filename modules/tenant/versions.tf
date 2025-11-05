terraform {
  required_version = ">= 1.2"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.53"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      # Required for non deprecated field name, rbac_authorization_enabled of keyvault
      version = ">= 4.42"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.8"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }
  }
}
