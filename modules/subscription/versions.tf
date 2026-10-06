terraform {
  # >= 1.4 required for the terraform_data resource used as the onboard re-POST trigger.
  required_version = ">= 1.4"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.111"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.8"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 2.11"
    }
  }
}
