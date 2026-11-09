# Federated credential for the sample service (ADR 0029). The identity is in the
# persistent root (ADR 0022) and is looked up by name. The credential holds the
# issuer URL of this cluster, so it is created and destroyed with the cluster.
# The namespace is the destination of gitops/dev/apps/sample-service.yaml. The
# service account name is the chart name.

data "azurerm_user_assigned_identity" "sample_service" {
  name                = "pp-${var.env}-sample-service"
  resource_group_name = "pp-${var.env}-persistent-rg"
}

resource "azurerm_federated_identity_credential" "sample_service" {
  name                      = "pp-${var.env}-sample-service"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.sample_service.id
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:apps:sample-service"
  audience                  = ["api://AzureADTokenExchange"]
}
