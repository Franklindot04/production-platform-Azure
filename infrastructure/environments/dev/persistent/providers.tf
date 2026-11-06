provider "azurerm" {
  features {}

  # The plan must not change the subscription. The providers this configuration needs are registered.
  resource_provider_registrations = "none"
}

# Uses the same sign-in as azurerm (Azure CLI). It holds no credentials.
provider "azuread" {}
