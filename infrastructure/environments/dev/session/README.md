# dev session layer

The resources of `dev` that are created at the start of a session and destroyed at the end. The configuration defines the resource group `pp-dev-session-rg`, the virtual network `pp-dev-vnet`, the node subnet `pp-dev-aks-nodes-snet` and the AKS cluster `pp-dev-aks` with one system pool, all in `swedencentral`. The cluster uses Azure Network Policy Manager ([ADR 0015](../../../../docs/adr/0015-network-policy-engine.md)) and the managed NGINX ingress of the application routing add-on, with no DNS zone ([ADR 0016](../../../../docs/adr/0016-ingress.md)). The network policy and the ingress setting have been planned and not applied: [saved plan](../../../../docs/plans/dev-session-plan-network-policy-and-ingress.txt). Managed Prometheus is planned and not applied ([ADR 0024](../../../../docs/adr/0024-managed-prometheus.md)): the `monitor_metrics` block on the cluster, and in `monitoring.tf` a data source for the Azure Monitor workspace of the persistent root, the data collection endpoint `pp-dev-prom-dce`, the data collection rule `pp-dev-prom-dcr` and the rule association. The saved plan above does not include them. Workload identity is planned and not applied ([ADR 0029](../../../../docs/adr/0029-workload-identity-and-vault-access.md)): the OIDC issuer, workload identity and the Key Vault secrets provider add-on (secret rotation off) on the cluster, and in `workload-identity.tf` a data source for the sample service identity of the persistent root and the federated credential for `system:serviceaccount:apps:sample-service`. The pool, the version pin and the upgrade settings are in [ADR 0012](../../../../docs/adr/0012-first-aks-plan.md). The ranges are in [ADR 0011](../../../../docs/adr/0011-session-network-design.md).

State file: `session.tfstate` in the `tfstate-dev` container, set in `backend.tf`. Initialise the backend with:

```bash
terraform -chdir=infrastructure/environments/dev/session init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The state account name is not committed. `.state-account-name` is written by `infrastructure/bootstrap/bootstrap.sh`. Access uses Microsoft Entra ID, so the signed-in user needs Storage Blob Data Contributor on the `tfstate-dev` container. The format and validate workflow runs `init -backend=false`, so it does not use the backend.


This root was applied once (ADR 0012) and then destroyed with `infrastructure/session.sh`. No resource from it exists now. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
