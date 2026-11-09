# Availability burn

## Trigger

One of two alerts in the rule group `pp-dev-slo-alerts` (`infrastructure/environments/dev/persistent/alerts.tf`, ADR 0028). Both compare the share of `/work` requests with a 5xx code to a threshold. Code 499 is not an error.

| Alert | Severity | Windows | Share of 5xx | For |
|---|---|---|---|---|
| AvailabilityFastBurn | 1 | 15m and 5m | above 0.144 | 2 minutes |
| AvailabilitySlowBurn | 2 | 1h and 15m | above 0.06 | 5 minutes |

The two differ in how fast the 30 day error budget (0.01) is used. At the fast burn rate (14.4) it is used up in about two days. At the slow burn rate (6) it is used up in about five days. Fast burn is severity 1 and is the one to act on first. Slow burn is severity 2. The response to each level is given as actions, not times: see the [severity table](../incident-process.md).

The alerts have not been applied and have not fired. This runbook is exercised by Session 2 experiment 3 (inject errors and latency), which is its first test.

## Impact

Part of the `/work` requests end with a 5xx code. If it continues, the availability budget (SLO 99%, `docs/slos.md`) is used up faster than the 30 days allow. Nothing in the repository says what the user sees beyond that.

## First checks

1. Run `monitoring/prometheus/error-ratio.promql` in the Prometheus explorer of the Azure Monitor workspace `pp-dev-amw` (planned, not run). It shows the current share of 5xx. Compare it with 0.144 and 0.06.
2. Run `monitoring/prometheus/request-rate.promql` the same way (planned, not run). It shows the rate by route. If `/work` has no requests, the alerts have no data and cannot fire.
3. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows whether the pods are ready, restarting or pending.
4. `kubectl get applications -n argocd` (planned, not run). It shows the sync and health state of `root`, `cluster-rules`, `sample-service` and `opentelemetry-collector`.
5. `kubectl logs -n apps deploy/sample-service` (planned, not run). It shows the log of one pod. There is no cluster-wide log collection (ADR 0019).
6. `kubectl port-forward -n apps deploy/sample-service 8081:8081`, then in a second terminal `curl http://localhost:8081/admin/config` (planned, not run). It shows the latency and the error rate set on that one pod. The admin port is not exposed by the Service. Repeat for each pod, because a setting applies to one pod only.

## Likely causes

- A non-zero error rate set through the admin port (`PUT /admin/config`). This is what experiment 3 does. See `applications/sample-service/README.md`.
- A bad image tag. See [bad-image-tag.md](bad-image-tag.md).
- Pods that are not ready. See [pod-not-ready.md](pod-not-ready.md).
- A network policy that blocks the service. See [network-policy-blocks-service.md](network-policy-blocks-service.md).
- The starting error rate in the chart values (`settings.errorRate`, default "0") was changed in Git.

Other causes are not known from the repository.

## Fix

1. If a pod has a non-zero error rate, set it back: `curl -X PUT http://localhost:8081/admin/config -d '{"error_rate":0}'` through a port-forward to that pod (planned, not run). It sets the error rate on that pod. Use `kubectl port-forward -n apps pod/<pod name> 8081:8081` to choose the pod.
2. Or delete the pods one at a time: `kubectl delete pod -n apps <pod name>` (planned, not run). The Deployment starts a new pod, and a new pod takes its starting values from the chart.
3. If the cause is a change in Git, revert the pull request that made it. Argo CD syncs the revert (automated sync). See [bad-image-tag.md](bad-image-tag.md).
4. Do not fix it by editing the Deployment with `kubectl`. Self-heal reverts it. See [argocd-drift.md](argocd-drift.md).

## Verify

1. Run `monitoring/prometheus/availability-sli.promql` (planned, not run). The SLI is back above the 99% target.
2. Run `monitoring/prometheus/error-ratio.promql` (planned, not run). The share is below 0.06.
3. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods are ready.
4. The alert is set to resolve by itself (`time_to_resolve` of 10 minutes in `alerts.tf`). How it behaves in Azure Monitor is not known.

## Rollback

The fix in step 1 and step 2 sets the service back to its chart values. There is nothing to undo. For a Git revert, revert the revert.

## Source

The alerts AvailabilityFastBurn and AvailabilitySlowBurn, ADR 0028, `docs/slos.md`, and Session 2 experiment 3.

## Status

not exercised
