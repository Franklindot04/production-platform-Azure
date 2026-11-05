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
| Pool upgrade surge | `max_surge = "1"` (the default, written down, not exercised) |
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

A plan does not check the VM size, the version or the quota against Azure, so the first real create (#35) tested the pool. The results are in the next section. They cover the create, not an upgrade or a node replacement.

## Result of the first create

The `dev` persistent root and then the `dev` session root were applied once, each from a saved plan that was shown and approved first. The cluster was read back, and then the session layer was destroyed. `session.sh check` found nothing left after the destroy.

AKS accepted the configuration. Read back with `az aks show` and `kubectl`:

| Setting | Result |
|---|---|
| Provisioning state | `Succeeded`, power state `Running` |
| Pool | `system`, mode `System`, 2 nodes of `Standard_D2s_v5`, autoscaler off, managed OS disk |
| Kubernetes version | 1.36.5 on the control plane and both nodes |
| Node provisioning | mode `Manual`, default node pools `None` |
| Cluster upgrade channel | `none`, with the Terraform attribute unset |
| Node OS upgrade channel | `None` |
| Pool `max_surge` | `1`. No upgrade was run, so the surge was not exercised. |
| Network | Azure CNI Overlay, pod range `10.244.0.0/16`, service range `10.96.0.0/16`, outbound through a load balancer |
| Tier and access | `Free`, public API limited to one authorized range, Entra ID RBAC not enabled, local accounts enabled |

The create needed no role for the cluster identity on the node subnet. Both nodes became `Ready`. A service of type LoadBalancer in that subnet was not tried.

Capacity of each node, read with `kubectl describe nodes` right after the create:

| | Per node | Both nodes |
|---|---|---|
| Capacity | 2 vCPU, 8126892 Ki memory | 4 vCPU |
| Allocatable | 1900m CPU, 5927340 Ki memory (about 5.65 GiB) | 3.8 vCPU, about 11.3 GiB |
| Requested by system pods | 767m CPU and 892 Mi on one node, 500m CPU and 666 Mi on the other | 1267m CPU (33% of allocatable), 1558 Mi (about 13%) |

That leaves about 2.5 vCPU and 9.8 GiB of requests on an idle cluster for the tools. The two nodes are separate, so one pod cannot use more than one node's share.

The cluster ran 20 pods, all `Running`, all in `kube-system`:

- On each node: `azure-cns`, `azure-ip-masq-agent`, `cloud-node-manager`, `csi-azuredisk-node`, `csi-azurefile-node` and `kube-proxy`.
- Two replicas: `coredns` and `konnectivity-agent`, one on each node, and `metrics-server`, both on the same node.
- One replica: `coredns-autoscaler` and `konnectivity-agent-autoscaler`.

AKS created these in the node resource group: a virtual machine scale set, a load balancer, a public IP address, a network security group and a user-assigned identity. `session.sh check` listed all of them while the cluster ran and none after the destroy.

Timing, as reported by Terraform. These are single runs, and the times are not an average:

| Step | Time |
|---|---|
| Persistent apply (one resource group) | 28 s |
| Session apply | about 7 minutes: resource group 28 s, virtual network 11 s, subnet 15 s, cluster 5 min 58 s |
| Session destroy | about 7 minutes: cluster 5 min 47 s, subnet 14 s, virtual network 12 s, resource group 30 s |

What the create did not test:

- An upgrade, a node replacement or a surge. With all 4 vCPU in use, a surge node cannot start. This follows from the quota and was not tried.
- The fit of Argo CD, the metrics agent, the OpenTelemetry Collector and the sample service. They do not exist yet.
- A second create after the destroy, and a create after a failed destroy.
- A LoadBalancer service, ingress, or network policy.
- Cost. It was not read.

Sizing against the in-cluster tools:

- Argo CD, the metrics agent, the OpenTelemetry Collector and the sample service do not exist yet. Their requests are not measured.
- The allocatable capacity is now read: 3.8 vCPU and about 11.3 GiB across both nodes, with about 1267m CPU and 1558 Mi requested by the system pods.
- The requests of each tool are not measured. Until they are, the sizing is not shown to fit. The measurement is part of Epic 3 (#3).

Limitations of this plan:

- Entra ID RBAC for the cluster is left for Epic 6 (#6). The cluster keeps local accounts for now.
- The provider turns the OIDC issuer on by default. Workload identity is off.
- `automatic_upgrade_channel` is left unset because the provider rejected `"none"`. AKS reports the channel as `none`, so unset means no automatic upgrades. The first real create confirmed this.
- Zones are not set.
- No network policy engine is set. It is chosen in Epic 3 (#3).

The plan output is saved in [docs/plans/](../plans/README.md). After the first create, the session layer was destroyed. The persistent resource group remains and is empty.

## Consequences

- A version or node image change means destroying and re-creating the cluster, which the session teardown already does.
- A failed destroy that leaves nodes behind keeps the quota in use and blocks the next create.
- A cluster of two small nodes has little room. Argo CD, the metrics agent and the OpenTelemetry Collector may not fit next to the sample service.
- A single node has no redundancy. A node failure takes the cluster down.
- A create takes about 7 minutes and a destroy about 7 minutes, so a session has about 14 minutes of waiting around the work. These are single runs.
- Cost is not estimated. Two nodes, their disks, the load balancer and its public IP address are billed while the cluster exists. The session layer is destroyed after each session (ADR 0009).
- The `Free` tier has no uptime SLA.

## Open questions

- Do the tools fit in the capacity that is left after the system pods, about 2.5 vCPU and 9.8 GiB of requests across two nodes?
- Does a LoadBalancer service work without a role for the cluster identity on the node subnet?
- Does AKS accept one `Standard_D4s_v5` node? Only the two-node pool was created.
- Does the quota need to be raised, and can it be?

## Alternatives considered

- Two `Standard_D4s_v5` nodes. Follows both guidelines. Needs 8 vCPU, which is above the quota.
- A separate user pool. Needs more quota than exists.
- Autoscaler on. It cannot add nodes beyond the quota.
- Automatic upgrade channels. They need surge room, which does not exist.
- Confidential-computing sizes in `northeurope`. Not needed, because standard sizes are available in `swedencentral`. Price not checked.
