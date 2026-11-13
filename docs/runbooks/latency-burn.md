# Latency burn

## Trigger

One of two alerts in the rule group `pp-dev-slo-alerts` (`infrastructure/environments/dev/persistent/alerts.tf`, ADR 0028). Both compare the share of `/work` requests slower than 0.5 seconds to a threshold.

| Alert | Severity | Windows | Share slower than 0.5 s | For |
|---|---|---|---|---|
| LatencyFastBurn | 1 | 15m and 5m | above 0.72 | 2 minutes |
| LatencySlowBurn | 2 | 1h and 15m | above 0.30 | 5 minutes |

The two differ in how fast the 30 day error budget (0.05) is used. At the fast burn rate (14.4) it is used up in about two days. At the slow burn rate (6) it is used up in about five days. Fast burn is severity 1 and is the one to act on first. Slow burn is severity 2. The response to each level is given as actions, not times: see the [severity table](../incident-process.md).

The alerts are applied. Both fired and resolved in [Session 3](../sessions/session-3-results.md) with latency injected on both pods. Session 2 injected errors and no latency.

## Impact

More than the allowed share of `/work` requests take longer than 0.5 seconds. If it continues, the latency budget (SLO 95% within 0.5 seconds, `docs/slos.md`) is used up faster than the 30 days allow.

## First checks

1. Run `monitoring/prometheus/latency-sli.promql` in the Prometheus explorer of the Azure Monitor workspace `pp-dev-amw`. It shows the share of requests within 0.5 seconds. Set the Prometheus explorer range to minutes with traffic.
2. Run `monitoring/prometheus/latency-p95.promql` the same way. It shows the 95th percentile of `/work`.
3. Run `monitoring/prometheus/request-rate.promql`. It shows the rate by route. A high rate points to load. No `/work` requests means the alerts have no data.
4. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows how many pods serve and where.
5. `kubectl top pods -n apps` (planned, not run). It shows CPU and memory use per pod. The pod CPU limit is 200m in the chart values. Whether it is reached is not known.
6. `kubectl port-forward -n apps deploy/sample-service 8081:8081`, then in a second terminal `curl http://localhost:8081/admin/config` (planned, not run). It shows the latency set on that one pod. Repeat for each pod, because a setting applies to one pod only.
7. Run `monitoring/logs/slow-requests.kql` in the Logs view of `pp-dev-law`. It lists slow requests from `AppRequests`. In Session 3 it listed `GET /work` rows with their duration in `DurationMs`.

## Likely causes

- A latency set through the admin port (`PUT /admin/config`). This is what the latency test in [Session 3](../sessions/session-3.md) does.
- Load above what the pods carry. The load test `ramp` scenario in `tests/load/README.md` finds that point. [Session 2](../sessions/session-2-results.md) ran it up to 160 requests per second: 62,818 requests, 0 failed, p95 427 ms. It records that 160 requests per second is not a breaking point.
- Fewer pods than the two in the chart, for example after a node drain. See [node-drain.md](node-drain.md).
- The starting latency in the chart values (`settings.latency`, default "0s") was changed in Git.
- CPU throttling at the pod limit. This is possible. It is not measured.

Other causes are not known from the repository.

## Fix

1. If a pod has a latency set, set it back: `curl -X PUT -H 'Content-Type: application/json' http://localhost:8081/admin/config -d '{"latency":"0s"}'` through a port-forward to that pod. It sets the latency on that pod. Use `kubectl port-forward -n apps pod/<pod name> 8081:8081` to choose the pod.
2. Or delete the pods one at a time: `kubectl delete pod -n apps <pod name>` (planned, not run). A new pod takes its starting values from the chart.
3. If the cause is load, stop the load test (stop `k6`).
4. If the cause is a change in Git, revert the pull request that made it. Argo CD syncs the revert (automated sync).
5. Do not fix it by editing the Deployment with `kubectl`. Self-heal reverts it. See [argocd-drift.md](argocd-drift.md).

## Verify

1. Run `monitoring/prometheus/latency-sli.promql`. The share within 0.5 seconds is back above the 95% target. Set the Prometheus explorer range to minutes with traffic.
2. Run `monitoring/prometheus/latency-p95.promql`. The value is below 0.5.
3. The alert is set to resolve by itself (`time_to_resolve` of 10 minutes in `alerts.tf`). In Session 3 LatencyFastBurn resolved 11 min 39 s and LatencySlowBurn resolved 20 min 38 s after the latency was set back.

## Rollback

The fix in step 1 and step 2 sets the service back to its chart values. There is nothing to undo. For a Git revert, revert the revert.

## Source

The alerts LatencyFastBurn and LatencySlowBurn, ADR 0028, `docs/slos.md`, and the latency test in [Session 3](../sessions/session-3.md).

## Status

exercised in Session 3. Both alerts fired and resolved with injected latency
