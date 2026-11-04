locals {
  tags = {
    project    = "production-platform-azure"
    env        = var.env
    managed-by = "terraform"
  }
}

resource "azurerm_resource_group" "session" {
  name     = "pp-${var.env}-session-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "pp-${var.env}-vnet"
  location            = azurerm_resource_group.session.location
  resource_group_name = azurerm_resource_group.session.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "pp-${var.env}-aks-nodes-snet"
  resource_group_name  = azurerm_resource_group.session.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.nodes_subnet_prefix]
}
