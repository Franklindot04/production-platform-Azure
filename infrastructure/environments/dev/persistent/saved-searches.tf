# The three KQL files in monitoring/logs are saved searches on the Log Analytics workspace (ADR 0031).
# Terraform reads the query text from the files, so the files stay the single source of the text.
locals {
  saved_searches = {
    failed-requests    = "Failed requests"
    slow-requests      = "Slow requests"
    trace-by-operation = "Trace by operation"
  }
}

resource "azurerm_log_analytics_saved_search" "kql" {
  for_each = local.saved_searches

  name                       = each.key
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = each.value
  category                   = "Sample service"
  query                      = file("${path.module}/../../../../monitoring/logs/${each.key}.kql")
  tags                       = local.tags
}
