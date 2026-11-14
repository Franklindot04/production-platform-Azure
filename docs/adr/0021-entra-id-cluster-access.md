# ADR 0021: Sign in to the cluster with Entra ID

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

The architecture document says that people sign in to the cluster with Microsoft Entra ID and Azure RBAC. The cluster created in the first create (ADR 0012) has Entra ID RBAC off and uses local accounts, with a certificate-based kubeconfig from `az aks get-credentials`. The maintainer can create applications and groups in the tenant.

## Decision

- Turn on the AKS-managed Entra ID integration with Azure RBAC for Kubernetes authorization, in the session Terraform.
- The object ID of the admin group is a run-time input and is not committed.
- Local accounts stay on as a fallback. They are not disabled, so a mistake cannot lock the maintainer out.
- The maintainer installs `kubelogin` and converts the kubeconfig to use it.
- The bootstrap step (ADR 0017) uses the local administrator credential, so that it never waits for an interactive sign-in.
- This work is first in the cut list of the delivery plan.

## Consequences

- Day-to-day access uses Entra ID. The local credential remains a way in for anyone who has rights to fetch it, so it is protected by Azure roles on the cluster resource.
- An interactive sign-in is needed for `kubectl` after the cluster is created.
- A role assignment on the cluster is needed for the maintainer or the group.
- The cluster was created with the Entra ID integration and Azure RBAC, on the node pool of ADR 0012 (two `Standard_D2s_v5` nodes). In Session 1 `kubelogin` sign-in in Azure CLI mode with the non-admin kubeconfig listed the nodes through the admin group and Azure RBAC (Session 1 results).
- The integration on the cluster, the variable `cluster_admin_group_object_id` and the two role assignments for the group (`access.tf`) are in the session root and are applied with it. The role assignments are destroyed with the cluster.

## Alternatives considered

- Local accounts only, as today. No sign-in step, and no individual identity in the audit trail.
- Local accounts disabled. Cleaner, but a mistake with the group or `kubelogin` locks the maintainer out of a cluster that lives only during a session.
