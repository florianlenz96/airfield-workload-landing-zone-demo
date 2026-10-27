terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # The state container comes with the landing zone; the pipeline fills in the rest.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    storage {
      # The storage account has no public endpoint, so the GitHub runner can't reach
      # its data plane. Terraform manages it through Azure Resource Manager only.
      data_plane_available = false
    }
  }
  subscription_id                 = var.landing_zone.subscription_id
  resource_provider_registrations = "none" # registered once by the platform team
  storage_use_azuread             = true   # no shared keys anywhere
}
