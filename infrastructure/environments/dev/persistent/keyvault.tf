data "azurerm_client_config" "current" {}

resource "random_string" "key_vault_suffix" {
  length  = 6
  upper   = false
  special = false
}

# Roles on the vault are assigned in workload-identity.tf: Key Vault Secrets User for the
# sample service identity, and Key Vault Secrets Officer for the principal that runs apply.
resource "azurerm_key_vault" "main" {
  name                       = "pp${var.env}kv${random_string.key_vault_suffix.result}"
  resource_group_name        = azurerm_resource_group.persistent.name
  location                   = azurerm_resource_group.persistent.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}
