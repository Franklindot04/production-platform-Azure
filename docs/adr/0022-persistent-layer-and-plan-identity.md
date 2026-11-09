# ADR 0022: Define the persistent layer and the pull request plan identity

- Status: proposed
- Date: 2026-11-06
- Issue: #37, #42, #35

## Context

The persistent root of `dev` defines only the resource group. ADR 0008, ADR 0009 and ADR 0019 place the monitoring workspaces, Application Insights and Key Vault in this layer. ADR 0007 says pull request runs use a read-only identity to run `terraform plan`. None of these resources is defined in Terraform yet, and nothing is applied.

Pull requests that change `infrastructure/` run format and validate checks only. They do not show what a change would do in Azure.

## Decision

Persistent root of `dev`:

- An Azure Monitor workspace for Prometheus metrics (ADR 0008).
- A Log Analytics workspace. Retention is 30 days and the daily ingestion cap is 0.5 GB. Both are variables with those defaults.
- A workspace-based Application Insights resource linked to the Log Analytics workspace, for traces (ADR 0019).
- An action group with one email receiver. The address is the sensitive variable `alert_email`. It is set at run time with `TF_VAR_alert_email` and is not written to any file. It is stored in the Terraform state, which is in the private state container. Alert rules are not part of this change.
- A Key Vault with Azure RBAC authorization, 7 days of soft delete and purge protection off. The name is `pp<env>kv` plus a 6-character random suffix, following ADR 0003. No role assignment is made on the vault. Who reads secrets is decided with the workload identity work.

Pull request plan identity (ADR 0007):

- An Entra application and service principal with no client secret.
- One federated credential. The issuer is GitHub Actions. The subject is `repo:<owner>@<owner-id>/<name>@<repo-id>:pull_request`, where the repository is a variable that defaults to this repository. GitHub presents the subject with the numeric owner and repository IDs, and Terraform takes them as run-time inputs. Only runs triggered by a pull request in that repository can get a token.
- Reader on the persistent resource group, and Storage Blob Data Reader on the `tfstate-dev` container. The container scope is built from the state account name, which is a variable set at run time with `TF_VAR_state_account_name`, so the Terraform code does not read the storage account.
- The workflow `terraform-plan.yml` logs in with `azure/login` and runs `terraform plan -lock=false` for both `dev` roots. The persistent plan also uses `-refresh=false`. Because the identity can only read, the plan does not take the state lease. The workflow does nothing for pull requests from forks, and it does nothing when the secret `AZURE_CLIENT_ID` is not set.
- The client ID, tenant ID, subscription ID and state account name are stored as GitHub secrets. They are identifiers, not credentials.

Assumptions:

- Azure Monitor workspaces can be created in `swedencentral`. Not checked.
- The Entra tenant allows the maintainer to create applications and federated credentials (ADR 0007). Not checked.
- The signed-in maintainer can create role assignments, which needs Owner or User Access Administrator on the scopes. The maintainer is Owner of the subscription (ADR 0010).

## Consequences

- Metric, log and trace storage outlive the session layer.
- Log Analytics ingestion is capped at 0.5 GB a day. Data over the cap is dropped until the next day. Costs are not estimated here.
- Key Vault with purge protection off can be deleted and purged, so the name can be reused. A deleted vault is kept for 7 days.
- The plan identity needs a first apply from the maintainer's machine before the workflow can run. Until the secrets are set, the workflow only prints a notice.
- Persistent plans in pull requests use a placeholder email address, so the plan shows a change to the action group receiver. Plans use `-refresh=false`, so they compare the configuration with the state and do not read Azure.
- The session plan refreshes the state. If the session layer exists, the identity has no read access to it and the plan fails. With the session layer destroyed, the state is empty and the plan works.
- The federated credential does not cover `push` or other events. Apply stays on the maintainer's machine.
- The `azuread` and `random` providers are new, and the lock file of the persistent root must be regenerated.

## Alternatives considered

- A client secret in GitHub secrets. A stored long-lived credential (ADR 0007).
- A subject limited to a GitHub environment. It would need a protected environment on the repository, which is not set up. The subject can be narrowed later.
- Reader on the whole subscription. Wider than a plan needs (ADR 0010).
- Look up the state container with a data source. The identity would need Reader on the state resource group.
- Application Insights without a workspace. Classic resources are retired (ADR 0019).
- A Key Vault with an access policy model. Azure RBAC is the current model and matches workload identity.
