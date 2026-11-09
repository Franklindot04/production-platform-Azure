locals {
  tags = {
    project    = "production-platform-azure"
    env        = var.env
    managed-by = "terraform"
  }
}

data "azurerm_client_config" "current" {}

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

resource "azurerm_kubernetes_cluster" "main" {
  name                = "pp-${var.env}-aks"
  location            = azurerm_resource_group.session.location
  resource_group_name = azurerm_resource_group.session.name
  dns_prefix          = "pp-${var.env}-aks"
  node_resource_group = "pp-${var.env}-aks-nodes-rg"

  kubernetes_version      = var.kubernetes_version
  node_os_upgrade_channel = "None"

  sku_tier                          = "Free"
  private_cluster_enabled           = false
  role_based_access_control_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    auto_scaling_enabled = false
    vnet_subnet_id       = azurerm_subnet.aks_nodes.id
    os_disk_type         = "Managed"
    os_disk_size_gb      = 32

    upgrade_settings {
      max_surge = "1"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode               = "Manual"
    default_node_pools = "None"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_authorized_ip_ranges
  }

  # Sign in with Entra ID and authorize with Azure RBAC (ADR 0021). Local accounts
  # stay on as the fallback, so local_account_disabled is not set. The roles for the
  # admin group are in access.tf.
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Workload identity and the Key Vault secrets provider add-on (ADR 0029).
  # The federated credential is in workload-identity.tf.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  # The managed NGINX ingress (ADR 0016). No DNS zone: the service is reached
  # by the public address of the load balancer, over HTTP.
  web_app_routing {
    dns_zone_ids             = []
    default_nginx_controller = "External"
  }

  # Managed Prometheus (ADR 0024). The rule and the association are in monitoring.tf.
  monitor_metrics {}

  tags = local.tags
}
