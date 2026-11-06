resource "azurerm_monitor_workspace" "main" {
  name                = "pp-${var.env}-amw"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  tags                = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "pp-${var.env}-law"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_cap_gb
  tags                = local.tags
}

# Workspace-based. Traces from the Collector go here (ADR 0019).
resource "azurerm_application_insights" "main" {
  name                = "pp-${var.env}-appi"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "main" {
  name                = "pp-${var.env}-alerts"
  resource_group_name = azurerm_resource_group.persistent.name
  short_name          = "pp${var.env}alert"
  tags                = local.tags

  email_receiver {
    name                    = "maintainer"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}
