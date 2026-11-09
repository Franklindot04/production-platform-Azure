# Network policy blocks the service

## Trigger

Probes of the sample service fail, or requests do not reach the pods, because a network policy blocks the path. Session 2 experiment 6 applies a blocking policy on purpose. It is optional there.

## Impact

The namespace `apps` has a default-deny policy for ingress and egress. Only the paths in `kubernetes/network-policies/apps.yaml` are open:

| Policy | Allows |
|---|---|
| `allow-dns` | Egress to `kube-dns` in `kube-system`, port 53 |
| `allow-ingress-controller` | Ingress to the sample service on port 8080 from `app-routing-system` |
| `allow-egress-to-collector` | Egress from the sample service to the Collector in `observability`, ports 4317 and 4318 |
| `allow-metrics-scrape` | Ingress to the sample service on port 8081 from pods labelled `rsName: ama-metrics` in `kube-system` |

The hypothesis of experiment 6 is that the probes fail and the alert fires. Two things are not known:

- Whether kubelet probes pass under default deny on AKS. It was checked on `kind` only (`kubernetes/README.md`).
- Whether an alert fires. If no request reaches the pods, the service counts no requests and the alert expressions return no data. A service that receives no requests produces no alert (`docs/slos.md`).

The repository has no manifest for the experiment policy. Which policy the experiment applies is not known.

## First checks

1. `kubectl get networkpolicy -n apps` (planned, not run). It lists the policies. Compare with `default-deny` and the four above.
2. `kubectl describe networkpolicy <policy name> -n apps` (planned, not run). It shows what the policy selects and allows.
3. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). It shows whether the pods are ready.
4. `kubectl describe pod -n apps <pod name>` (planned, not run). The events show readiness and liveness probe failures.
5. `kubectl get endpoints sample-service -n apps` (planned, not run). A pod that is not ready is missing from the list.
6. `SCENARIO=smoke BASE_URL=http://<ingress address> k6 run tests/load/sample-service.js` (planned, not run). It shows whether requests through the ingress succeed.

## Likely causes

- A policy that was added by hand and selects the sample service pods.
- One of the four allow policies was deleted or changed by hand. Argo CD restores policies that are in `kubernetes/` (the Application `cluster-rules`). See [argocd-drift.md](argocd-drift.md).
- A change to `kubernetes/network-policies/` in Git that removed a path.
- The engine does not enforce policies the way the files assume. The first create tests the engine setting (ADR 0015). Enforcement and probe behaviour on AKS are checked in Session 1.

Other causes are not known from the repository.

## Fix

1. If the policy was added by hand, delete it: `kubectl delete networkpolicy <policy name> -n apps` (planned, not run). It removes the policy.
2. If a policy from Git was deleted or changed by hand, wait for Argo CD to restore it, or follow [argocd-drift.md](argocd-drift.md).
3. If the cause is a change in Git, revert the pull request that made it. Argo CD syncs the revert.
4. Do not delete `default-deny` to get traffic through. Add the missing allow rule in Git.

## Verify

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods are ready.
2. `kubectl get endpoints sample-service -n apps` (planned, not run). Both pod addresses are listed.
3. `SCENARIO=smoke BASE_URL=http://<ingress address> k6 run tests/load/sample-service.js` (planned, not run). The checks pass.

## Rollback

If you deleted a policy that was in Git, Argo CD restores it. If you deleted one that was not, apply it again from the file you kept. Nothing else to undo.

## Source

Session 2 experiment 6, ADR 0015, `kubernetes/README.md`, `kubernetes/network-policies/apps.yaml`.

## Status

not exercised
