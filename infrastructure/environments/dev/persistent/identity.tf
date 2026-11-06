# Identity for pull request plans (ADR 0007, ADR 0022). It has no client secret.
# A pull request run gets a token only when the workflow runs for a pull request.

locals {
  state_container_id = join("/", [
    "/subscriptions", data.azurerm_client_config.current.subscription_id,
    "resourceGroups", var.state_resource_group_name,
    "providers/Microsoft.Storage/storageAccounts", var.state_account_name,
    "blobServices/default/containers", "tfstate-${var.env}",
  ])
}

resource "azuread_application" "plan" {
  display_name     = "pp-${var.env}-pr-plan"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "plan" {
  client_id = azuread_application.plan.client_id
}

resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.plan.id
  display_name   = "github-pull-request"
  description    = "Pull request runs of ${var.github_repository}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:pull_request"
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = azurerm_resource_group.persistent.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.plan.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_state_reader" {
  scope                = local.state_container_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_service_principal.plan.object_id
  principal_type       = "ServicePrincipal"
}
