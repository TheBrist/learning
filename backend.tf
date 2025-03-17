terraform {
  backend "azurerm" {
    resource_group_name = "netanel"
    storage_account_name = "terraformstate4321"
    container_name = "tfstate"
    key = "terraform.tfstate"
  }
}