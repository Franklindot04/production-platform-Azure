# ADR 0010: Separate environments by resource group

- Status: proposed
- Date: 2026-11-04
- Issue: #16

## Context

The project plans three environments: `dev`, `staging` and `prod`. They need a boundary for names, state, access, cost, quota and policy. The project has one maintainer, one Entra ID tenant and one planned subscription.

Azure offers two common boundaries: one subscription per environment, or one subscription with one set of resource groups per environment. Separate subscriptions are a stronger boundary. They also need more setup.

## Decision

Environments are separated by resource group inside one subscription.

Resource groups:

- Per environment, two resource groups: `pp-<env>-persistent-rg` and `pp-<env>-session-rg`. The persistent layer and the session layer are described in the architecture document.
- AKS also creates a node resource group. Terraform names it `pp-<env>-aks-nodes-rg`.
- The state storage account serves all environments, so it sits in its own resource group, `pp-shared-state-rg`, in `northeurope`. The environment resource groups are in `swedencentral`. The account is named `ppsharedstate` plus a suffix drawn by the bootstrap script. `shared` is used as the name segment where `<env>` would be. It is not an environment. Resources there carry the tag `env=shared`.

Persistent layer per environment: Key Vault and the Azure Monitor and Log Analytics workspaces. Each environment has its own. The container registry is not in Azure (ADR 0013).

Terraform layout:

- Each environment is its own Terraform root, with one persistent and one session configuration. The planned path is `infrastructure/environments/<env>/`. Shared code goes in modules.
- Terraform workspaces are not used.
- Environment inputs are written in `.tf` files. `.gitignore` excludes `*.tfvars`, so committed variable files named `dev.tfvars` would be ignored.

State, extending ADR 0004:

- One blob container per environment in the shared storage account, named `tfstate-<env>`.
- Two state files per environment, one per layer: `persistent.tfstate` and `session.tfstate`. State is separate per environment and per layer.

Access:

- Role assignments for an environment are scoped to its resource groups, plus a data role on its state container.
- Each environment has its own pipeline identity. The federated credential subject is limited to the GitHub environment with the same name, as described in ADR 0007.
- Pull request runs use a read-only identity for `terraform plan`.
- The maintainer is Owner of the subscription. This is not a boundary between environments. The resource group split limits pipelines and other identities, not the maintainer.

Cost:

- Every resource carries the tags from ADR 0003, so cost can be filtered by environment.
- A budget with alerts is planned for each environment (ADR 0009). Whether a budget can be scoped to a resource group is not checked.
- Resources are tagged, and the session layer is destroyed after each session (ADR 0009).

Policy: policy is assigned per environment resource group where the policy tool allows it. A subscription-wide assignment is used only for a rule that applies to every environment. Scans run in CI and no admission policy engine runs in the cluster (ADR 0020).

Creation:

- Only `dev` is created first.
- `staging` and `prod` are defined here. Their resource groups, containers, state files and directories are not created until they are needed.

Promotion path:

- Infrastructure: pull request, plan, review, merge, then apply to `dev` from the maintainer's machine. The same change is applied to `staging`, then `prod`, only after the previous environment is checked.
- Workloads: a pull request changes the values under `gitops/<env>/`, first for `dev`, then `staging`, then `prod`. A workflow opens the pull request that changes the image tag (ADR 0018).
- Rollback is a Git revert in both paths.
- The check between environments is not defined yet. It is written when the sample service and its health checks exist.

Teardown: ADR 0009 applies to every environment, including `prod` if it is created. Keeping `prod` running between sessions means revisiting ADR 0009.

Assumptions:

- One storage account serves all environments. This follows from the maintainer's choice and is not tested.
- Federated credentials and GitHub environments work as described in ADR 0007. This is not checked.
- Resource group scope is enough for the roles Terraform needs. Role assignments by Terraform may need a higher role than Contributor. This is not checked.
- Only one environment runs at a time (ADR 0009).

## Consequences

What gets easier:

- Names, state and roles are separate per environment from the first day, although only `dev` exists.
- A mistake in one environment's Terraform stays in its state and resource groups.
- Cost can be filtered by environment with tags and resource group views.

Limits of this model:

- Quota is per subscription and region, so all environments share it. The target subscription has a regional vCPU quota of 4. A second cluster would use most or all of it, so only one environment runs at a time.
- The budget is shared. One environment can use up what the others need.
- A subscription-level failure affects every environment. Examples are a disabled subscription, a deny policy at subscription scope, and exhausted quota.
- The tenant is shared. A mistake in tenant-level identity settings affects every environment.
- The state storage account is shared. Losing it loses the state of every environment. Versioning and soft delete reduce that risk but do not remove it.
- The maintainer's Owner role covers every environment.
- `prod` is a name for the most protected environment. It is not a service with uptime, because the session layer is destroyed after each session.

What gets harder:

- Moving to separate subscriptions later means re-creating resources and migrating state.
- Each new environment needs its own root, containers, identities and role assignments.
- The bootstrap step creates the shared resource group and the state account by hand. It also creates the per-environment containers.

## Alternatives considered

- One subscription per environment. Stronger boundary for quota, budget and subscription-level failure. More setup. Can be revisited if the project outgrows this model.
- One resource group with tags only. No access boundary, and a destroy could reach other environments.
- Terraform workspaces. All environments share one backend configuration, and it is easy to apply to the wrong environment.
- One state storage account per environment. Listed in ADR 0004. Not chosen, because there is one maintainer and per-environment containers already separate access to state.
- One shared state container. Not chosen, because a data role is assigned at account or container scope, not for one key. Every pipeline identity would reach every environment's state.
