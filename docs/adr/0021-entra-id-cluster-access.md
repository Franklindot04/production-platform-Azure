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
- The first create without Entra ID is the only cluster tested so far. Whether the integration works with the pool in ADR 0012 is not tested.

## Alternatives considered

- Local accounts only, as today. No sign-in step, and no individual identity in the audit trail.
- Local accounts disabled. Cleaner, but a mistake with the group or `kubelogin` locks the maintainer out of a cluster that lives only during a session.
