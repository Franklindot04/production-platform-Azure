# Roles and secret rules

Who and what has access, and how secrets are handled. Each statement names the file that defines it. Where a file does not define a role, the row says so.

Status values:

- applied: the resource exists, or the state is stated as built in `docs/architecture.md`.
- written and not applied: the code exists and has not been applied to Azure.
- in the repository: a GitHub Actions workflow. Whether it has run on GitHub is in `docs/workflows.md`.
- planned: no code exists yet.

## 1. Roles

| Who or what | For | Role or permission | Scope | Defined in | Status |
|---|---|---|---|---|---|
| The maintainer | Owns the subscription and every environment | Owner | Every environment. ADR 0010 does not name the scope | Stated in `docs/adr/0010-environment-separation.md`. Not defined in code | Applied |
| The maintainer | Reads and writes Terraform state | Storage Blob Data Contributor | The container `tfstate-<env>` | `infrastructure/bootstrap/bootstrap.sh` (step `role`) | Applied |
| The maintainer, running `terraform apply` on the persistent root | Sets Key Vault secret values by hand | Key Vault Secrets Officer, for the principal that runs apply | The Key Vault | `infrastructure/environments/dev/persistent/workload-identity.tf` | Written and not applied |
| The maintainer, running `terraform apply` on the persistent root | Creates the plan identity and its role assignments | Permission to create applications in the Entra tenant and to create role assignments. No role is named | The Entra tenant, and role assignments | `infrastructure/environments/dev/persistent/README.md` | Planned. It is needed when the persistent root is applied |
| Pull request plan identity `pp-<env>-pr-plan` | `terraform plan` on pull requests | Reader | The persistent resource group | `infrastructure/environments/dev/persistent/identity.tf` | Written and not applied |
| Pull request plan identity | Reads Terraform state during a plan | Storage Blob Data Reader | The container `tfstate-<env>` | `infrastructure/environments/dev/persistent/identity.tf` | Written and not applied |
| Sample service identity `pp-<env>-sample-service` | Reads one Key Vault secret from the pods | Key Vault Secrets User | The Key Vault | `infrastructure/environments/dev/persistent/workload-identity.tf` | Written and not applied |
| Workflows Terraform checks, Service, chart and manifest checks, Security scans | Checks on pull requests | `contents: read` | The repository | `.github/workflows/terraform-checks.yml`, `app-checks.yml`, `security-scans.yml` | In the repository |
| Workflow Terraform plan | Logs in to Azure as the plan identity | `contents: read` and `id-token: write`, in the one job. No permissions at the top | The repository, and a token for the federated credential | `.github/workflows/terraform-plan.yml` | In the repository |
| Workflow Publish image | Pushes the sample service image | `contents: read` at the top, and `packages: write` in the one job | The repository and its package on `ghcr.io` | `.github/workflows/image-publish.yml` | In the repository |
| Workflow Open pull request for the image tag | Opens a pull request that changes the tag | `contents: write` and `pull-requests: write`, in the one job. No permissions at the top | The repository | `.github/workflows/image-tag-bump.yml` | In the repository |
| Argo CD admin credential | Signs in to Argo CD | The admin credential that Argo CD generates when it starts, read from the cluster when asked | The Argo CD instance of the session cluster | `docs/adr/0017-argocd-bootstrap.md`, `infrastructure/session.sh` (`argocd-password`) | Written. The session layer is destroyed |
| Administrator credential of the session cluster | Lets `session.sh bootstrap` and `argocd-password` reach the cluster | The local administrator credential from `az aks get-credentials --admin` | The session cluster | `infrastructure/session.sh` (`kube_setup`), `docs/adr/0021-entra-id-cluster-access.md` | Written. The session layer is destroyed |
| People, to the cluster | Day-to-day `kubectl` | Entra ID sign-in with Azure RBAC for Kubernetes. The admin group is a run-time input | The session cluster | `docs/adr/0021-entra-id-cluster-access.md`, issue #45 | Planned |

Notes on the rows:

- The plan identity federated credential has the subject `repo:<owner>/<name>:pull_request`. Pull requests from forks get no token and no secrets (`.github/workflows/terraform-plan.yml`). The plan identity has no role on the session resource group (`docs/workflows.md`).
- The workflow Terraform plan reads the repository secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TFSTATE_ACCOUNT_NAME`. They hold identifiers and no credential (`docs/workflows.md`). Publish image logs in to `ghcr.io` with the built-in token, and the tag workflow uses the built-in token.
- The kubeconfig that `session.sh` fetches is written outside the repository, with mode 600 (`infrastructure/session.sh`, `kube_setup`). The script stops if `PP_PLAN_DIR` is inside the repository.
- The bootstrap step keeps using the local administrator credential after Entra ID access is added, and local accounts stay on as a fallback (`docs/adr/0021-entra-id-cluster-access.md`).

### How a role is added

A new role, scope or permission is added in a pull request that changes this table in the same commit set as the code that grants it. A role that is not in the table is not granted.

## 2. Secret rules

1. **Where each kind of secret lives.**
   - The Key Vault holds the secret `sample-service-secret`, which the sample service reads as a file (`docs/adr/0029-workload-identity-and-vault-access.md`).
   - GitHub repository secrets hold identifiers for the plan workflow (`docs/workflows.md`). They are not credentials.
   - The cluster secret `appinsights-connection` is created at run time in the namespace `observability` (`infrastructure/session.sh`, `create_collector_secret`). It lives with the cluster.
   - Terraform state holds some sensitive values (rule 5).
2. **Never in Git:** secret values, account identifiers (subscription, tenant and client IDs), the maintainer's address ranges, and email addresses. The identity client ID and the vault name are read from Terraform outputs at run time (`docs/adr/0029-workload-identity-and-vault-access.md`). The alert email and the authorized ranges are run-time inputs (`infrastructure/environments/dev/persistent/README.md`, `infrastructure/README.md`).
3. **What keeps them out of Git.**
   - `.gitignore` covers `*.tfvars`, state files, `kubeconfig`, `.env` files, key and certificate files, and `infrastructure/bootstrap/.state-account-name`.
   - GitHub secret scanning and push protection are on for this repository (`docs/architecture.md`, section 10).
   - The Security scans workflow scans the files and the sample service image for secrets, and a finding of severity HIGH or CRITICAL fails the run (`.github/workflows/security-scans.yml`, ADR 0020). An accepted finding needs a reason in `.trivyignore.yaml`.
   - The output of `session.sh` replaces GUIDs and `/32` host ranges (`infrastructure/session.sh`, `mask`).
4. **Run-time pattern.** The session script reads a value when it is needed, passes it through a pipe or the environment, and never prints it or writes it to a file (`infrastructure/session.sh`).
   - The `secrets` part pipes the connection string from the Terraform output straight into the cluster.
   - The `identity` part passes the client ID, the tenant ID and the vault name to a helper in its environment, and sends the patch to `kubectl` on a pipe.
   - `argocd-password` refuses to print unless the output is a terminal (ADR 0017).
   - Inputs such as `TF_VAR_alert_email` and `TF_VAR_api_authorized_ip_ranges` are set in the shell and not written to a file.
5. **Terraform state.** State can contain sensitive values (ADR 0004). It holds the Application Insights connection string, which is a sensitive output (`infrastructure/environments/dev/persistent/outputs.tf`), the alert email, and the authorized ranges (`infrastructure/README.md`). It does not hold the Key Vault secret value (ADR 0029). Access is with Entra ID only, and shared key access is off. The maintainer has Storage Blob Data Contributor on the container. The plan identity will have Storage Blob Data Reader on it, so a pull request plan can read state. The plan output is not saved (`docs/workflows.md`).
6. **Images are public and hold no secret** (ADR 0013). The sample service image is a public package on `ghcr.io`, and anyone can pull it.
7. **Rotation is manual.**
   - The Key Vault secret: rotation is off in the add-on (`infrastructure/environments/dev/session/main.tf`). To change the value, set a new one with the step in `infrastructure/README.md`. The pods read it after they restart (ADR 0029).
   - The cluster secret `appinsights-connection`: `session.sh bootstrap secrets` creates it from the state again. No other rotation process is written.
8. **If a secret leaks:** rotate it first. Then report it as in `SECURITY.md`, through private vulnerability reporting and not a public issue. The repository is public (ADR 0007), so treat a pushed value as exposed even after the commit is removed.
9. **Setting the Key Vault secret.** The one-time step is in `infrastructure/README.md`. It is planned and has not run.

## 3. Not done yet

- Entra ID access for people to the cluster (issue #45, ADR 0021).
- The network rule on the Key Vault. The scan finding AZU-0013 is accepted in `.trivyignore.yaml` (ADR 0029).
- Every role marked "written and not applied" above: the plan identity, the sample service identity and the Key Vault Secrets Officer role.
- A rotation process for the cluster secret.
