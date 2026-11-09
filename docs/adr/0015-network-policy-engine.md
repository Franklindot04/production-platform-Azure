# ADR 0015: Use Azure network policy

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

ADR 0005 chose Azure CNI Overlay and left the network policy engine open. The cluster needs default-deny policies with explicit allowed paths.

Facts read from the AKS documentation:

- AKS offers three engines: Cilium (with Azure CNI Powered by Cilium), Azure Network Policy Manager (NPM) and Calico. The documentation recommends Cilium for new deployments.
- Azure NPM is set with `network_policy = "azure"`.
- AKS no longer supports Azure NPM on Linux nodes from 30 September 2028. It no longer supports it on Windows nodes from 30 September 2026.
- Azure NPM does not support more than 250 nodes and 20,000 pods, and it does not support IPv6.
- The pages read do not say whether Azure NPM or Calico work with Azure CNI Overlay. The Cilium example uses overlay with `network_policy = "cilium"` and `network_data_plane = "cilium"`.
- The CPU and memory that Azure NPM uses, and its pod count, are not stated.
- Changing the engine on an existing cluster reimages every node pool at the same time.

## Decision

- Use Azure Network Policy Manager. It is Azure's own engine, and it is set in the session Terraform with `network_policy = "azure"`.
- Namespaces start with a default-deny policy. Allowed paths are listed in the manifests under `kubernetes/` (issue #30).
- The end of support in 2028 is after the planned life of this project. The cluster is also re-created each session, so a change of engine needs no migration.

Assumption: Azure NPM works with Azure CNI Overlay on this cluster. The documentation does not state it, and a plan does not check it. The first create tests it. If AKS refuses the setting, the create fails and the work stops. If it is accepted, Session 1 checks that a test pod in another namespace is blocked.

Fallback: Cilium, set with `network_data_plane = "cilium"` and `network_policy = "cilium"`. It replaces the data plane, and its resource use is not measured. Using it needs a new decision.

## Consequences

- The CPU and memory of the NPM pods are measured in Session 1 against the capacity budget.
- Policies must keep to what Azure NPM supports. The documentation warns that editing a large policy can cause short connectivity problems, and it advises four or fewer `ipBlock` sections.
- `kind` does not show whether policies are enforced on AKS.

## Alternatives considered

- Cilium. Recommended by the documentation for new clusters, and shown with overlay. It changes the data plane, and its resource use is not known.
- Calico. AKS does not test or support features beyond the standard Kubernetes policies.
- No network policy. No isolation between namespaces.
