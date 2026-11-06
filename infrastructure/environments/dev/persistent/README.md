# dev persistent layer

The resources of `dev` that outlive a session. The resource group `pp-dev-persistent-rg` in `swedencentral` was applied once. The files below are written and not applied, so every resource in them is planned. The container registry is an open question.

| File | Defines |
|---|---|
| `main.tf` | The resource group and the tags. |
| `monitoring.tf` | An Azure Monitor workspace, a Log Analytics workspace (30 days, 0.5 GB a day), a workspace-based Application Insights resource and an action group with one email receiver (ADR 0008, ADR 0019, ADR 0022). |
| `keyvault.tf` | A Key Vault with Azure RBAC authorization, 7 days of soft delete and purge protection off. The name has a random suffix. No role is assigned on it. |
| `identity.tf` | An Entra application, service principal and one federated credential for pull request plans, Reader on the resource group and Storage Blob Data Reader on the `tfstate-dev` container. It has no client secret (ADR 0007, ADR 0022). |
| `outputs.tf` | Resource IDs, the vault name and the client ID of the plan identity. The Application Insights connection string is a sensitive output. |

## Inputs set at run time

These have no default and are not written to any file:

```bash
export TF_VAR_alert_email="<address that receives alerts>"
export TF_VAR_state_account_name="$(cat infrastructure/bootstrap/.state-account-name)"
```

`alert_email` must look like an email address. It is stored in the state. `github_repository` defaults to this repository and sets the subject of the federated credential: `repo:<owner>/<name>:pull_request`.

Applying `identity.tf` needs permission to create applications in the Entra tenant and to create role assignments. After the apply, store the output `plan_identity_client_id`, the tenant ID, the subscription ID and the state account name as the repository secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TFSTATE_ACCOUNT_NAME`. Until `AZURE_CLIENT_ID` is set, the plan workflow does nothing (`docs/workflows.md`).

The lock file must be regenerated with `terraform init -upgrade` after the `azuread` and `random` providers were added.

State file: `persistent.tfstate` in the `tfstate-dev` container, set in `backend.tf`. Initialise the backend with:

```bash
terraform -chdir=infrastructure/environments/dev/persistent init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The state account name is not committed. `.state-account-name` is written by `infrastructure/bootstrap/bootstrap.sh`. Access uses Microsoft Entra ID, so the signed-in user needs Storage Blob Data Contributor on the `tfstate-dev` container. The pull request plan identity has the read role only. The format and validate workflow runs `init -backend=false`, so it does not use the backend.


The resource group `pp-dev-persistent-rg` exists and is empty. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.
