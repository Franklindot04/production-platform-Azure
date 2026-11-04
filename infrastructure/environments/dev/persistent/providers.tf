provider "azurerm" {
  features {}

  # The plan must not change the subscription. The providers this configuration needs are registered.
  resource_provider_registrations = "none"
}
