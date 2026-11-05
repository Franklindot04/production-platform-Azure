# dev persistent layer

The resources of `dev` that outlive a session. The configuration defines the resource group `pp-dev-persistent-rg` in `swedencentral`. Key Vault and the monitoring workspaces are planned. The container registry is an open question.

State file: `persistent.tfstate` in the `tfstate-dev` container, set in `backend.tf`. Initialise the backend with:

```bash
terraform -chdir=infrastructure/environments/dev/persistent init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The state account name is not committed. `.state-account-name` is written by `infrastructure/bootstrap/bootstrap.sh`. Access uses Microsoft Entra ID, so the signed-in user needs Storage Blob Data Contributor on the `tfstate-dev` container. The format and validate workflow runs `init -backend=false`, so it does not use the backend.


Nothing in this root has been applied. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
