# ADR 0012: Plan the first AKS cluster

- Status: proposed
- Date: 2026-11-04
- Issue: #28

## Context

The target subscription has a regional vCPU quota of 4 in `swedencentral` (ADR 0003). The cluster has to fit in it, and so does any node that AKS adds during an upgrade.

Facts read with the Azure CLI and the Azure API, without creating anything:

- In `swedencentral`, `Standard_D2s_v5` (2 vCPU, 8 GB) and `Standard_D4s_v5` (4 vCPU, 16 GB) are available. Both are in the `DSv5` family, whose quota is 4. The total regional quota is 4. Nothing is in use.
- Neither size supports ephemeral OS disks, so the pool uses a managed OS disk.
- In `northeurope`, the standard sizes with 2 or 4 vCPU were not available. Only confidential-computing sizes were available there. That is why the workloads are in `swedencentral`.
- The default Kubernetes minor version in `swedencentral` is 1.36. Its newest patch is 1.36.5. Version 1.37 exists and is not the default.

Facts read from the AKS documentation:

- A system node pool needs nodes of at least 4 vCPU and 4 GB, and at least two nodes.
- An upgrade adds a surge node first. The default is one extra node. It needs free quota. Max surge 0 is only allowed when max unavailable is above 0, and max unavailable cannot be set on a system pool.

## Decision

The first plan is one system pool and no user pool.

| Setting | Value |
|---|---|
| Pool name and mode | `system` (system pool) |
| Node size and count | `Standard_D2s_v5` × 2, which is 4 vCPU and 16 GB in total |
| Recorded alternative | `Standard_D4s_v5` × 1, which is 4 vCPU and 16 GB in total |
| Autoscaler | off |
| OS disk | managed, 32 GB |
| Pool upgrade surge | `max_surge = "1"` (the default, written down) |
| Kubernetes version | 1.36.5, pinned |
| Cluster upgrade channel | not set (see the limitations) |
| Node OS upgrade channel | `None` |
| Node provisioning | `Manual`, no default node pools |
| Tier | `Free` |
| Access | public API with authorized ranges (ADR 0005), Entra ID RBAC not enabled |
| Network | Azure CNI Overlay and the ranges in ADR 0011 |

Both options break an AKS guideline:

- Two `Standard_D2s_v5` nodes break the 4 vCPU per node minimum.
- One `Standard_D4s_v5` node breaks the two-node minimum.

Neither option leaves room for a surge node. Both use the whole quota of 4 vCPU. A surge node cannot start, so an in-place upgrade or a node replacement fails. The policy is to pin the version, leave upgrades off and re-create the cluster to change a version or a node image. Max surge 0 is not available on a system pool, so the default of 1 is kept. It cannot start without free quota.

**The pool setup is unproven.** Terraform plans the setting, but a plan does not check the VM size, the version or the quota against Azure. Whether AKS accepts either option is only known by a real create. That happens under Epic 3 (#3). If AKS refuses both, the plan needs a different region, a higher quota or another size.

Sizing against the in-cluster tools:

- Argo CD, the metrics agent, the OpenTelemetry Collector and the sample service do not exist yet. Their requests are not measured.
- The CPU and memory that AKS reserves on a node are not read. The usable capacity of 4 vCPU and 16 GB is therefore not known.
- The check is a measurement under Epic 3 (#3): record the allocatable capacity of the nodes, then the requests of each tool. Until then, the sizing is not shown to fit.

Limitations of this plan:

- Entra ID RBAC for the cluster is left for Epic 6 (#6). The cluster keeps local accounts for now.
- The provider turns the OIDC issuer on by default. Workload identity is off.
- `automatic_upgrade_channel` is left unset because the provider rejected `"none"`. That unset means no automatic upgrades is not confirmed. The first real create confirms it or not.
- Zones are not set.
- No network policy engine is set. It is chosen in Epic 3 (#3).

The plan output is saved in [docs/plans/](../plans/README.md). Nothing is applied.

## Consequences

- A version or node image change means destroying and re-creating the cluster, which the session teardown already does.
- A failed destroy that leaves nodes behind keeps the quota in use and blocks the next create.
- A cluster of two small nodes has little room. Argo CD, the metrics agent and the OpenTelemetry Collector may not fit next to the sample service.
- A single node has no redundancy. A node failure takes the cluster down.
- Cost is not estimated. Two nodes, their disks, the load balancer and its public IP address are billed while the cluster exists. The session layer is destroyed after each session (ADR 0009).
- The `Free` tier has no uptime SLA.

## Open questions

- Does AKS accept two `Standard_D2s_v5` nodes, or one `Standard_D4s_v5` node, as a system pool in this subscription?
- How much capacity is left for the tools after the system pods?
- Does the quota need to be raised, and can it be?

## Alternatives considered

- Two `Standard_D4s_v5` nodes. Follows both guidelines. Needs 8 vCPU, which is above the quota.
- A separate user pool. Needs more quota than exists.
- Autoscaler on. It cannot add nodes beyond the quota.
- Automatic upgrade channels. They need surge room, which does not exist.
- Confidential-computing sizes in `northeurope`. Not needed, because standard sizes are available in `swedencentral`. Price not checked.
