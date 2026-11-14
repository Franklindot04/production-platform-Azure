# The dashboards of the sample service are one Azure Monitor workbook (ADR 0032).
# Terraform reads the query text from the files in monitoring/, so the files stay the single source of the text.
# The lists keep the order of the items. The workspace ids come from the resources in this layer.
locals {
  workbook_prometheus = [
    { key = "request-rate", title = "Request rate", description = "Requests per second by route" },
    { key = "availability-sli", title = "Availability SLI", description = "Availability SLI: share of `/work` requests without a 5xx code" },
    { key = "error-ratio", title = "Error ratio", description = "Share of `/work` requests with a 5xx code. Code 499 is not an error" },
    { key = "latency-sli", title = "Latency SLI", description = "Latency SLI: share of `/work` requests within 0.5 seconds" },
    { key = "latency-p95", title = "Latency p95", description = "95th percentile latency of `/work`" },
    { key = "abandoned-requests", title = "Abandoned requests", description = "Rate of `/work` requests with code 499" },
  ]

  workbook_kql = [
    { key = "failed-requests", title = "Failed requests", description = "Failed `/work` requests, newest first" },
    { key = "slow-requests", title = "Slow requests", description = "`/work` requests slower than a threshold set at the top of the file" },
  ]

  workbook_items = concat(
    flatten([
      for q in local.workbook_prometheus : [
        {
          type    = 1
          name    = "${q.key}-title"
          content = { json = "### ${q.title}\n${q.description}" }
        },
        {
          type = 3
          name = "${q.key}-chart"
          content = {
            version = "KqlItem/1.0"
            query = jsonencode({
              version        = "PrometheusQueryProvider/1.0"
              customEndpoint = false
              queryText      = file("${path.module}/../../../../monitoring/prometheus/${q.key}.promql")
              type           = "query_range"
            })
            size          = 0
            timeContext   = { durationMs = 86400000 }
            queryType     = 16
            resourceType  = "microsoft.monitor/accounts"
            visualization = "timechart"
          }
        },
      ]
    ]),
    flatten([
      for q in local.workbook_kql : [
        {
          type    = 1
          name    = "${q.key}-title"
          content = { json = "### ${q.title}\n${q.description}" }
        },
        {
          type = 3
          name = "${q.key}-table"
          content = {
            version                 = "KqlItem/1.0"
            query                   = file("${path.module}/../../../../monitoring/logs/${q.key}.kql")
            size                    = 0
            timeContext             = { durationMs = 86400000 }
            queryType               = 0
            resourceType            = "microsoft.operationalinsights/workspaces"
            crossComponentResources = [azurerm_log_analytics_workspace.main.id]
            visualization           = "table"
          }
        },
      ]
    ]),
  )
}

resource "azurerm_application_insights_workbook" "service" {
  name                = uuidv5("dns", "sample-service-workbook.pp-${var.env}")
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  display_name        = "Sample service"
  source_id           = lower(azurerm_monitor_workspace.main.id)
  tags                = local.tags

  data_json = jsonencode({
    version             = "Notebook/1.0"
    items               = local.workbook_items
    layout              = { type = "flow" }
    fallbackResourceIds = [azurerm_monitor_workspace.main.id]
    "$schema"           = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  })
}
