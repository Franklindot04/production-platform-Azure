# infrastructure

Terraform for the platform. The persistent root of `dev` is applied. The session root of `dev` was applied once, and the session layer was destroyed after the first create.

- `bootstrap/`: the Azure CLI script that creates the state backend. It is not a Terraform root.
- `modules/`: shared modules. Planned.
- `environments/<env>/`: one folder per environment, each with a persistent and a session root. Only `dev` exists. `staging` and `prod` are added when they are needed.

The persistent root defines the monitoring workspaces, the alerts, the Key Vault, the identity for pull request plans (ADR 0022), and the identity of the sample service with its Key Vault roles (ADR 0029). All of it is applied. The session root also contains written, not applied, workload identity settings on the cluster and the federated credential for the sample service (ADR 0029). Those resources are planned until they are applied.

There are two Terraform roots today, `environments/dev/persistent` and `environments/dev/session`. Each environment root is its own Terraform configuration. Terraform workspaces are not used. Environment inputs are written in `.tf` files, because `.gitignore` excludes `*.tfvars`.

## Resource providers

The subscription must have these resource providers registered before the persistent apply: Microsoft.AlertsManagement, Microsoft.Insights, Microsoft.Monitor, Microsoft.OperationalInsights, Microsoft.KeyVault, Microsoft.ManagedIdentity and Microsoft.Authorization. The session apply also needs Microsoft.ContainerService, Microsoft.Network and Microsoft.Compute.

The Terraform provider blocks do not register providers. Register one with:

```bash
az provider register --namespace <name> --wait
```

Check one with:

```bash
az provider show --namespace <name> --query registrationState -o tsv
```

The expected output is `Registered`.

## Session script

`session.sh` creates, destroys and checks the session layer of an environment. It needs the Azure CLI signed in, Terraform, and the state backend from `bootstrap/`. It reads the state account name from `bootstrap/.state-account-name`, which is not committed. Output is masked: GUIDs and every `/32` host range are replaced.

| Command | What it does |
|---|---|
| `session.sh up` | Initialises the backend and saves a plan. Nothing is created. |
| `session.sh up --apply` | Applies the saved plan. The session layer bills until it is destroyed. |
| `session.sh down` | Shows the destroy plan. Nothing is destroyed. |
| `session.sh down --yes` | Destroys the session root. |
| `session.sh check` | Lists every resource by resource group and reports what remains. |
| `session.sh bootstrap` | Installs Argo CD with Helm, sets the source range of the ingress, applies the root Application, and creates the Collector secret. It can be repeated. |
| `session.sh bootstrap identity` | Reads the identity client ID and the vault name from the persistent root and the tenant from the signed-in account, and sets them as Helm parameters on the Argo CD Application `sample-service`, with the Key Vault mount on (ADR 0029). |
| `session.sh bootstrap secrets` | Creates only the secret `appinsights-connection` in the namespace `observability`. It ran in Session 1 and set the Application Insights connection secret. |
| `session.sh argocd-password` | Prints the Argo CD admin credential to the terminal. |

### Create the Entra ID admin group

The group name is a name and not an ID. The group ID is read at run time and is not written to a file. Create the group once and add the maintainer to it:

```bash
az ad group create --display-name pp-dev-cluster-admins --mail-nickname pp-dev-cluster-admins --query displayName -o tsv
az ad group member add --group pp-dev-cluster-admins --member-id "$(az ad signed-in-user show --query id -o tsv)"
```

### Entra ID sign-in

Session 1 ran these steps: the nodes were listed with the non-admin kubeconfig through the admin group and Azure RBAC. `kubelogin` must be installed.

Each session, before `session.sh up`, set the group ID:

```bash
export TF_VAR_cluster_admin_group_object_id="$(az ad group show --group pp-dev-cluster-admins --query id -o tsv)"
```

After the cluster exists, fetch the kubeconfig without `--admin` into a file outside the repository, and convert it to sign in with the Azure CLI:

```bash
export KUBECONFIG="${PP_PLAN_DIR:-${TMPDIR:-/tmp}}/kubeconfig-dev-user"
az aks get-credentials --overwrite-existing --file "$KUBECONFIG" -g pp-dev-session-rg -n pp-dev-aks
kubelogin convert-kubeconfig -l azurecli
kubectl get nodes
```

`session.sh bootstrap` keeps using the local administrator credential (ADR 0021).

### Set the Key Vault secret

The sample service pods do not start until the secret `sample-service-secret` exists in the vault. Set it once, after the persistent root is applied. The value is read from a prompt and not from the command line, and the output is limited to the secret ID.

```bash
IFS= read -r -s -p "Secret value: " PP_SECRET_VALUE; echo
printf '%s' "$PP_SECRET_VALUE" | az keyvault secret set \
  --vault-name "$(terraform -chdir=infrastructure/environments/dev/persistent output -raw key_vault_name)" \
  --name sample-service-secret --file /dev/stdin --query id -o tsv
unset PP_SECRET_VALUE
```

The signed-in user needs the role Key Vault Secrets Officer on the vault (ADR 0029).

`dev` is the default environment. Pass `staging` or `prod` as the second argument for another one.

`up` needs the authorized API range in `TF_VAR_api_authorized_ip_ranges`, a JSON list of CIDR ranges. Set it at run time and do not write it to a file. The saved plan holds the range, so it is kept outside the repository: `PP_PLAN_DIR` sets the folder and defaults to the temporary folder. The range is also stored in the state, which is in the private state container.

`up` also needs the object ID of the Entra ID admin group in `TF_VAR_cluster_admin_group_object_id` (ADR 0021). Set it at run time and do not write it to a file. The session root gives the group two roles on the cluster in `access.tf`. This is written and not applied. `down` uses a placeholder value if the variable is not set, because a destroy only needs a valid value.

`check` exits 1 if any of these remain, and 0 otherwise:

- the session resource group or the AKS node resource group,
- a cluster, virtual machine or scale set,
- a public IP address, a load balancer or a managed disk,
- a resource group that is not `pp-shared-state-rg`, the persistent group of the environment, `NetworkWatcherRG`, or `MA_pp-<env>-amw_<region>_managed` (made by Azure for the Monitor workspace).

Azure creates `NetworkWatcherRG` when a virtual network exists in a region, and it is not counted. Azure creates the `MA_` group when the Monitor workspace exists, and `check` does not count it. `check` prints names and counts, never IDs. Run it at the end of every session (ADR 0009).

`bootstrap` and `argocd-password` use the administrator credential of the session cluster, which `az aks get-credentials` writes to a kubeconfig file outside the repository (`PP_PLAN_DIR`). `PP_KUBE_CONTEXT` uses an existing kubectl context instead. The ingress source range comes from `PP_INGRESS_ALLOWED_RANGES`, a comma separated list, or else from `TF_VAR_api_authorized_ip_ranges`. `bootstrap` stops if neither is set or if the range is open to everyone. The `secrets` part reads the Application Insights connection string from the output `application_insights_connection_string` of the persistent root when it runs, and creates the cluster secret `appinsights-connection` in the namespace `observability` (ADR 0025). The value only travels through pipes. It is not printed, masked, stored or written to a file. The part waits up to 5 minutes for the namespace, and it stops if the output is empty. A kind cluster has no Azure state, so a full bootstrap skips this part there, and `bootstrap secrets` with `PP_KUBE_CONTEXT` set stops with exit code 2. The Argo CD credential is generated by Argo CD and read from the cluster when `argocd-password` is run. The command refuses to print it when the output is not a terminal, and nothing stores it. The UI is reached with `kubectl -n argocd port-forward svc/argocd-server 8080:443`.

Seen in the first run:

- The first `session.sh up` against a state key that did not exist yet stopped with "Error acquiring the state lock" and a connection reset. Nothing was created. Running it again worked. The cause is not confirmed.
- `session.sh down` needs no authorized range. It uses a documentation address for the variable, and the real range comes from the state. The mask replaces every `/32` range, so the address is not printed.

See [ADR 0010](../docs/adr/0010-environment-separation.md) and section 9 of [the architecture document](../docs/architecture.md).
