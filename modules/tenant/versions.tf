terraform {
  required_version = ">= 1.2"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.53"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
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
