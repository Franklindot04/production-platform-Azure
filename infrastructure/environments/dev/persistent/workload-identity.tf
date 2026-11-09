# Identity of the sample service (ADR 0029). The federated credential for it
# is in the session root, because the issuer URL changes with every cluster.
resource "azurerm_user_assigned_identity" "sample_service" {
  name                = "pp-${var.env}-sample-service"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  tags                = local.tags
}

# Reads secret values. It cannot create or change them.
resource "azurerm_role_assignment" "sample_service_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.sample_service.principal_id
  principal_type       = "ServicePrincipal"
}

# Lets the maintainer set secret values by hand. Issue #43 reviews roles.
resource "azurerm_role_assignment" "maintainer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
