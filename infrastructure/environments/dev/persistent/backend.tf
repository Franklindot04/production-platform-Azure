terraform {
  backend "azurerm" {
    container_name   = "tfstate-dev"
    key              = "persistent.tfstate"
    use_azuread_auth = true
  }
}
