# Alert for missing request data (ADR 0033).
#
# The rule group is in the session layer, so it exists only while the cluster exists.
# It cannot fire between sessions, when no cluster runs.
# The probes call /readyz, so the series exists whenever a pod runs, with or without /work traffic.
# A new cluster needs about 13 minutes to reach Healthy (772 seconds in Session 2), so the wait is 15 minutes.
data "azurerm_monitor_action_group" "main" {
  name                = "pp-${var.env}-alerts"
  resource_group_name = "pp-${var.env}-persistent-rg"
}

resource "azurerm_monitor_alert_prometheus_rule_group" "session" {
  name                = "pp-${var.env}-session-alerts"
  resource_group_name = azurerm_resource_group.session.name
  location            = azurerm_resource_group.session.location
  scopes              = [data.azurerm_monitor_workspace.main.id]
  interval            = "PT1M"
  rule_group_enabled  = true
  description         = "Alert for missing request data from the sample service."
  tags                = local.tags

  rule {
    alert    = "MissingRequestData"
    for      = "PT15M"
    severity = 2
    enabled  = true

    expression = <<-EOT
      absent_over_time(http_requests_total{route="/readyz"}[5m])
    EOT

    labels = {
      slo = "data"
    }

    annotations = {
      summary     = "No request data from the sample service"
      description = "The workspace has had no http_requests_total series for route /readyz for 15 minutes. The sample service is down or its metrics do not reach the workspace."
    }

    action {
      action_group_id = data.azurerm_monitor_action_group.main.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }
  }
}
