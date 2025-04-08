terraform {
  backend "azurerm" {
    resource_group_name = "netanel"
    storage_account_name = "terraformstate4321"
    container_name = "tfstate"
    key = "terraform.tfstate"
  }
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.18.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.20.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.20.0"
    }
  }
}

provider "google" {
  region = var.region
}


provider "azurerm" {
  features {}
  subscription_id = "cb6a7a77-cdd1-4d79-974a-d6917ccb4ff7"
}