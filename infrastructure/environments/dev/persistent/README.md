# dev persistent layer

The resources of `dev` that outlive a session. The configuration defines the resource group `pp-dev-persistent-rg` in `swedencentral`. Key Vault and the monitoring workspaces are planned. The container registry is an open question.

State file: `persistent.tfstate` in the `tfstate-dev` container. The backend is not configured in this root. Plans are run from a copy of the root with local state.

Nothing in this root has been applied. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
