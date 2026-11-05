# infrastructure

Terraform for the platform. The `dev` roots were applied once. The persistent resource group exists and is empty. The session layer was destroyed after the first create.

- `bootstrap/`: the Azure CLI script that creates the state backend. It is not a Terraform root.
- `modules/`: shared modules. Planned.
- `environments/<env>/`: one folder per environment, each with a persistent and a session root. Only `dev` exists. `staging` and `prod` are added when they are needed.

There are two Terraform roots today, `environments/dev/persistent` and `environments/dev/session`. Each environment root is its own Terraform configuration. Terraform workspaces are not used. Environment inputs are written in `.tf` files, because `.gitignore` excludes `*.tfvars`.

## Session script

`session.sh` creates, destroys and checks the session layer of an environment. It needs the Azure CLI signed in, Terraform, and the state backend from `bootstrap/`. It reads the state account name from `bootstrap/.state-account-name`, which is not committed. Output is masked: GUIDs and every `/32` host range are replaced.

| Command | What it does |
|---|---|
| `session.sh up` | Initialises the backend and saves a plan. Nothing is created. |
| `session.sh up --apply` | Applies the saved plan. The session layer bills until it is destroyed. |
| `session.sh down` | Shows the destroy plan. Nothing is destroyed. |
| `session.sh down --yes` | Destroys the session root. |
| `session.sh check` | Lists every resource by resource group and reports what remains. |

`dev` is the default environment. Pass `staging` or `prod` as the second argument for another one.

`up` needs the authorized API range in `TF_VAR_api_authorized_ip_ranges`, a JSON list of CIDR ranges. Set it at run time and do not write it to a file. The saved plan holds the range, so it is kept outside the repository: `PP_PLAN_DIR` sets the folder and defaults to the temporary folder. The range is also stored in the state, which is in the private state container.

`check` exits 1 if any of these remain, and 0 otherwise:

- the session resource group or the AKS node resource group,
- a cluster, virtual machine or scale set,
- a public IP address, a load balancer or a managed disk,
- a resource group that is not `pp-shared-state-rg`, the persistent group of the environment, or `NetworkWatcherRG`.

Azure creates `NetworkWatcherRG` when a virtual network exists in a region, and it is not counted. `check` prints names and counts, never IDs. Run it at the end of every session (ADR 0009).

See [ADR 0010](../docs/adr/0010-environment-separation.md) and section 9 of [the architecture document](../docs/architecture.md).
