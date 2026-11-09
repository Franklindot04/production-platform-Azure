# dev persistent layer

The resources of `dev` that outlive a session. Every resource in the files below is applied. The resource group is `pp-dev-persistent-rg` in `swedencentral`. Images are stored in `ghcr.io`, outside Azure, so this layer has no registry (ADR 0013).

| File | Defines |
|---|---|
| `main.tf` | The resource group and the tags. |
| `monitoring.tf` | An Azure Monitor workspace, a Log Analytics workspace (30 days, 0.5 GB a day), a workspace-based Application Insights resource and an action group with one email receiver (ADR 0008, ADR 0019, ADR 0022). |
| `alerts.tf` | A Prometheus rule group `pp-dev-slo-alerts` in the Azure Monitor workspace with four burn-rate alerts that send to the action group (ADR 0028). |
| `keyvault.tf` | A Key Vault with Azure RBAC authorization, 7 days of soft delete and purge protection off. The name has a random suffix. The roles on it are in `workload-identity.tf`. |
| `workload-identity.tf` | A user-assigned managed identity `pp-dev-sample-service` for the sample service, with Key Vault Secrets User on the vault. The principal that runs apply gets Key Vault Secrets Officer, to set secret values by hand (the roles are listed in [docs/security.md](../../../../docs/security.md)). The secret value is not in Terraform or in state. The federated credential is in the session root (ADR 0029). |
| `identity.tf` | An Entra application, service principal and one federated credential for pull request plans, Reader on the resource group and Storage Blob Data Reader on the `tfstate-dev` container. It has no client secret (ADR 0007, ADR 0022). |
| `outputs.tf` | Resource IDs, the vault name, the client ID of the plan identity, and the name and client ID of the sample service identity. The Application Insights connection string is a sensitive output. |

## Inputs set at run time

These have no default and are not written to any file:

```bash
export TF_VAR_alert_email="<address that receives alerts>"
export TF_VAR_state_account_name="$(cat infrastructure/bootstrap/.state-account-name)"
export TF_VAR_github_owner_id="$(gh api repos/<owner>/<name> --jq .owner.id)"
export TF_VAR_github_repository_id="$(gh api repos/<owner>/<name> --jq .id)"
```

The two GitHub IDs are not secret. They are not written to a file.

`alert_email` must look like an email address. It is stored in the state. `github_repository` defaults to this repository. With the two IDs it sets the subject of the federated credential: `repo:<owner>@<owner-id>/<name>@<repo-id>:pull_request`. GitHub presents the subject with the numeric owner and repository IDs, and Terraform takes them as run-time inputs.

Applying `identity.tf` needs permission to create applications in the Entra tenant and to create role assignments. After the apply, store the output `plan_identity_client_id`, the tenant ID, the subscription ID and the state account name as the repository secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TFSTATE_ACCOUNT_NAME`. Until `AZURE_CLIENT_ID` is set, the plan workflow does nothing (`docs/workflows.md`).

State file: `persistent.tfstate` in the `tfstate-dev` container, set in `backend.tf`. Initialise the backend with:

```bash
terraform -chdir=infrastructure/environments/dev/persistent init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The state account name is not committed. `.state-account-name` is written by `infrastructure/bootstrap/bootstrap.sh`. Access uses Microsoft Entra ID, so the signed-in user needs Storage Blob Data Contributor on the `tfstate-dev` container. The pull request plan identity has the read role only. The format and validate workflow runs `init -backend=false`, so it does not use the backend.

The resource group `pp-dev-persistent-rg` holds the resources defined by the files above. Azure creates two things around them: the resource group `MA_pp-dev-amw_swedencentral_managed` for the Monitor workspace, and an action group named "Application Insights Smart Detection" in the persistent resource group. Neither is defined in Terraform. The provider block does not register resource providers, and it holds no credentials. Terraform reads the subscription from `ARM_SUBSCRIPTION_ID` and the Azure CLI login.

The resource providers that must be registered are listed in [Resource providers](../../../README.md#resource-providers).
