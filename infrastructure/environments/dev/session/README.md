# dev session layer

The resources of `dev` that are created at the start of a session and destroyed at the end. The configuration defines the resource group `pp-dev-session-rg`, the virtual network `pp-dev-vnet` the node subnet `pp-dev-aks-nodes-snet` and the AKS cluster `pp-dev-aks` with one system pool, all in `swedencentral`. The pool, the version pin and the upgrade settings are in [ADR 0012](../../../../docs/adr/0012-first-aks-plan.md). The ranges are in [ADR 0011](../../../../docs/adr/0011-session-network-design.md).

State file: `session.tfstate` in the `tfstate-dev` container, set in `backend.tf`. Initialise the backend with:

```bash
terraform -chdir=infrastructure/environments/dev/session init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The state account name is not committed. `.state-account-name` is written by `infrastructure/bootstrap/bootstrap.sh`. Access uses Microsoft Entra ID, so the signed-in user needs Storage Blob Data Contributor on the `tfstate-dev` container. The format and validate workflow runs `init -backend=false`, so it does not use the backend.


This root was applied once (ADR 0012) and then destroyed with `infrastructure/session.sh`. No resource from it exists now. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
