# ADR 0011: Design the session network

- Status: proposed
- Date: 2026-11-04
- Issue: #23

## Context

The session layer holds the virtual network and the AKS cluster. ADR 0005 chose Azure CNI Overlay: nodes take addresses from the virtual network, and pods take addresses from a separate private range. This record fixes the address ranges, the subnets, how the authorized API range is set, and whether network security groups are used.

With Azure CNI Overlay, each node gets a fixed /24 from the pod range. The size of that block cannot be changed. The pod range must not overlap the cluster subnet or any network connected to the virtual network. The service range must not overlap the pod range, the cluster subnet or connected networks.

The ranges are inputs of the `dev` session root. Azure accepted them in the first create (ADR 0012): the network and the cluster were created with these ranges. The session layer was then destroyed, so no resource described here exists now.

## Decision

Virtual network, one per environment:

| Environment | Virtual network | Name |
|---|---|---|
| `dev` | `10.10.0.0/16` | `pp-dev-vnet` |
| `staging` | `10.20.0.0/16` (not created) | `pp-staging-vnet` |
| `prod` | `10.30.0.0/16` (not created) | `pp-prod-vnet` |

The ranges differ per environment, so the networks can be connected later without a renumbering.

Subnets in the `dev` network:

| Subnet | Range | Status |
|---|---|---|
| `pp-dev-aks-nodes-snet` | `10.10.0.0/24` | in the Terraform |
| (private endpoints) | `10.10.1.0/24` | reserved, not in the Terraform |

The node subnet holds the AKS nodes. A /24 gives 251 usable addresses. The cluster is limited to 4 vCPU by the subscription quota (ADR 0003), so it needs a handful of them, including one for an upgrade surge.

Cluster ranges:

| Range | Value |
|---|---|
| Pod range (overlay) | `10.244.0.0/16` |
| Service range | `10.96.0.0/16` |
| DNS service address | `10.96.0.10` |

The pod and service ranges are not routed outside the cluster, so every environment uses the same values. None of the ranges overlap: the three virtual networks, the pod range and the service range are disjoint, and both subnets are inside `10.10.0.0/16`.

Authorized API range:

- The API server is public, with access limited to authorized ranges (ADR 0005).
- The Terraform variable `api_authorized_ip_ranges` takes a list of CIDR ranges. It has no default. Terraform rejects an empty list, `0.0.0.0/0` and anything that is not a CIDR range.
- The value is supplied when Terraform runs, with the environment variable `TF_VAR_api_authorized_ip_ranges`. It is not committed, because it changes with the maintainer's address.
- The saved plan output uses `203.0.113.10/32`, an address reserved for documentation.

Network security groups:

- No network security group is created or attached to the node subnet. AKS creates and manages one for the cluster in its node resource group.
- This is revisited when ingress is designed under Epic 3 (#3), and with the network policy engine chosen for Epic 6 (#6).

Outbound traffic uses the default standard load balancer, which gets one public IP address.

## Consequences

- Address planning is small. Pods do not use virtual network addresses.
- The authorized range must be set on every run. A wrong range blocks `kubectl` and any Terraform step that calls the cluster.
- Reusing the pod and service ranges means pod traffic between two clusters would need a change. No such traffic is planned, and only one cluster runs at a time.
- The standard load balancer and its public IP address add cost. The amount is not estimated here.
- Without a custom network security group, the rules on the node network are the ones AKS sets. They are not reviewed here.

## Open questions

- How does ingress reach the cluster, and which ports are open?
- Is the reserved range used for private endpoints, for example to Key Vault?
- Is a NAT gateway needed for outbound traffic?
- Does the network policy engine need a different data plane setting?

## Alternatives considered

- A single network range for every environment. Simpler, but the environments could never be connected.
- A larger node subnet. Not needed with 4 vCPU of quota.
- A custom network security group on the node subnet. More control, and more rules to keep correct. Not needed before ingress exists.
- A private cluster. Listed in ADR 0005.
