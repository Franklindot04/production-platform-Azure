# dev session layer

The resources of `dev` that are created at the start of a session and destroyed at the end. The configuration defines the resource group `pp-dev-session-rg`, the virtual network `pp-dev-vnet` the node subnet `pp-dev-aks-nodes-snet` and the AKS cluster `pp-dev-aks` with one system pool, all in `swedencentral`. The pool, the version pin and the upgrade settings are in [ADR 0012](../../../../docs/adr/0012-first-aks-plan.md). The ranges are in [ADR 0011](../../../../docs/adr/0011-session-network-design.md).

State file: `session.tfstate` in the `tfstate-dev` container. The backend is not configured in this root. Plans are run from a copy of the root with local state.

Nothing in this root has been applied. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
