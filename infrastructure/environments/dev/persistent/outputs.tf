output "resource_group_name" {
  value = azurerm_resource_group.persistent.name
}

output "monitor_workspace_id" {
  value = azurerm_monitor_workspace.main.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "application_insights_id" {
  value = azurerm_application_insights.main.id
}

output "application_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "action_group_id" {
  value = azurerm_monitor_action_group.main.id
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "plan_identity_client_id" {
  description = "Client ID of the pull request plan identity. Store it as the secret AZURE_CLIENT_ID."
  value       = azuread_application.plan.client_id
}
