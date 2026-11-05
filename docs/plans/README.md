# Saved plans

Text output of `terraform plan` for the `dev` roots, run before the first create. They were run from copies of the roots with local state. The first create used new plans from the real backend, and its results are in [ADR 0012](../adr/0012-first-aks-plan.md).

| File | Root | Result |
|---|---|---|
| [dev-persistent-plan.txt](dev-persistent-plan.txt) | `infrastructure/environments/dev/persistent` | 1 to add |
| [dev-session-plan.txt](dev-session-plan.txt) | `infrastructure/environments/dev/session` | 4 to add |

How they were produced:

- The root was copied to a folder outside the repository and initialised there with its lock file. The copy has no backend, so state stayed local and the state storage account was not used.
- The subscription came from `ARM_SUBSCRIPTION_ID` and the Azure CLI login. The provider block holds no credentials and does not register resource providers.
- The session plan used `TF_VAR_api_authorized_ip_ranges` with `203.0.113.10/32`, an address reserved for documentation.
- Any GUID in the output is replaced with `xxxx`.

What a plan does not show:

- It does not check the VM size, the Kubernetes version or the vCPU quota against Azure. A real create does. The first create is in [ADR 0012](../adr/0012-first-aks-plan.md).
- Values marked `known after apply` are set by Azure.

To run a plan again, copy the root and its `.terraform.lock.hcl` to an empty folder, run `terraform init`, then `terraform plan`.
