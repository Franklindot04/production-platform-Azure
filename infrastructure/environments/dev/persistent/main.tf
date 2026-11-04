locals {
  tags = {
    project    = "production-platform-azure"
    env        = var.env
    managed-by = "terraform"
  }
}

resource "azurerm_resource_group" "persistent" {
  name     = "pp-${var.env}-persistent-rg"
  location = var.location
  tags     = local.tags
}
