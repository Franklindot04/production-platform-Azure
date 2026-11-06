# Managed Prometheus for the cluster (ADR 0024). The workspace is in the
# persistent root (ADR 0022) and is looked up by name. The endpoint, the rule
# and the association live and die with the cluster.

data "azurerm_monitor_workspace" "main" {
  name                = "pp-${var.env}-amw"
  resource_group_name = "pp-${var.env}-persistent-rg"
}

resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = "pp-${var.env}-prom-dce"
  resource_group_name = azurerm_resource_group.session.name
  location            = azurerm_resource_group.session.location
  kind                = "Linux"
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "pp-${var.env}-prom-dcr"
  resource_group_name         = azurerm_resource_group.session.name
  location                    = azurerm_resource_group.session.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  kind                        = "Linux"
  description                 = "Sends Prometheus metrics of the cluster to the Azure Monitor workspace."
  tags                        = local.tags

  destinations {
    monitor_account {
      monitor_account_id = data.azurerm_monitor_workspace.main.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }
}

# The name follows the Microsoft template for the add-on.
resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "MSProm-${var.location}-${azurerm_kubernetes_cluster.main.name}"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}
