# ADR 0005: Choose the AKS networking model

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

AKS offers several network plugins. The choice affects IP address use, available features, and how hard a later change is. The plugin can be hard to change on an existing cluster. Here, clusters are short-lived, so a change costs one re-create.

## Decision

- Use Azure CNI Overlay. Nodes get addresses from the virtual network. Pods get addresses from a separate private range.
- Use Azure Network Policy Manager to restrict pod traffic (ADR 0015).
- Assumption: the Kubernetes API server is public, with access limited to authorized IP ranges that contain the maintainer's address. A private cluster needs a VPN or jump host, which adds cost and setup time that the project does not need yet.

## Consequences

- Small virtual network address needs, since pods do not use VNet addresses.
- Pods are not directly reachable from other VNet resources without extra routing. This is acceptable because no such resource is planned.
- The authorized IP range must be updated when the maintainer's IP changes. This will be a recurring chore, and it must be handled in Terraform variables.
- A public API endpoint is a larger attack surface than a private one. Authorized ranges and Entra ID authentication reduce it.

## Alternatives considered

- kubenet. Microsoft has announced its retirement. The date must be checked in the Azure documentation before relying on it, and it is not needed here.
- Azure CNI with node subnet. Every pod uses a VNet address, which needs more address planning.
- Private cluster. Better exposure, but needs a VPN or jump host. Can be revisited later.
