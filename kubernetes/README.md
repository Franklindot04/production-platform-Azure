# kubernetes

Plain manifests for cluster-level rules. Argo CD syncs this folder (`gitops/dev/apps/cluster-rules.yaml`).

| Path | Content |
|---|---|
| `namespaces/` | `apps`, `observability` and `argocd`, with Pod Security Admission labels. `apps` enforces the restricted profile. The other two enforce baseline and warn and audit against restricted. |
| `quotas/` | A resource quota and a limit range for `apps` and `observability` |
| `network-policies/` | Default deny for `apps` and `observability`, then the allowed paths |

## Initial budget

About 2.5 vCPU and 9.8 GiB of requests are left on the two nodes after the system pods (ADR 0012). The quotas are a first split of that. They are not measured and are changed after a live session.

| Namespace | Requests (CPU, memory) | Limits (CPU, memory) | Pods |
|---|---|---|---|
| `apps` | 500m, 1Gi | 1, 2Gi | 20 |
| `observability` | 300m, 512Mi | 600m, 1Gi | 10 |
| `argocd` | no quota | no quota | no limit |

The `argocd` namespace has no quota and no network policy, so that the bootstrap does not depend on rules that are untested on AKS. It is not isolated.

## Network policies

The engine is Azure Network Policy Manager (ADR 0015).

- `apps`: ingress to the sample service on port 8080 from `app-routing-system`, egress to DNS, and egress to the Collector on ports 4317 and 4318.
- `observability`: ingress to the Collector on ports 4317 and 4318 from `apps`, egress to DNS, and egress to port 443.

The Collector and the ingress controller do not exist yet. The policies that name them allow nothing until they do.

Whether the policies are enforced on AKS, and whether kubelet probes pass under default deny, is checked in a live session. On `kind` both were checked: see `tests/kind/check.sh`.

## Check

```bash
kubeconform -strict -summary -kubernetes-version 1.36.0 kubernetes
```
