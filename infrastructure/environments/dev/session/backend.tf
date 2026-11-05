terraform {
  backend "azurerm" {
    container_name   = "tfstate-dev"
    key              = "session.tfstate"
    use_azuread_auth = true
  }
}
