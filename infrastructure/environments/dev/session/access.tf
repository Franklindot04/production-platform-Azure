# Roles for the Entra ID admin group on the cluster (ADR 0021). They are destroyed
# with the cluster. The table in docs/security.md (issue #43) lists them.

resource "azurerm_role_assignment" "cluster_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.cluster_admin_group_object_id
  principal_type       = "Group"
}

# Lets the group fetch the kubeconfig with az aks get-credentials.
resource "azurerm_role_assignment" "cluster_user" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.cluster_admin_group_object_id
  principal_type       = "Group"
}
