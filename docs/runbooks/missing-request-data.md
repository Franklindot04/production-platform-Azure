# Missing request data

## Trigger

The alert MissingRequestData (severity 2) in the rule group `pp-dev-session-alerts` (`infrastructure/environments/dev/session/alerts.tf`, ADR 0033). It fires when the Azure Monitor workspace `pp-dev-amw` has had no `http_requests_total` series for the route `/readyz` for 15 minutes. The rule group exists only while the cluster exists.

## Impact

The burn-rate alerts (ADR 0028) have no data and cannot fire. A service that is down looks quiet. The probes call `/readyz`, so the series exists whenever a pod runs. No series means that no pod runs, or that the metrics do not reach the workspace.

The alert is written. It is not yet applied or exercised.

## First checks

1. Run `monitoring/prometheus/request-rate.promql` in the Prometheus explorer of the Azure Monitor workspace `pp-dev-amw` (planned, not run). It shows the rate by route. No `/readyz` series confirms the alert.
2. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows whether the pods are ready, restarting or pending.
3. `kubectl get applications -n argocd` (planned, not run). It shows the sync and health state of `root`, `cluster-rules`, `sample-service` and `opentelemetry-collector`.
4. `kubectl get pods -n observability` (planned, not run). It shows whether the OpenTelemetry Collector pods run.
5. `kubectl get pods -n kube-system` (planned, not run). The metrics agent pods carry the label `rsName: ama-metrics` (`docs/runbooks/network-policy-blocks-service.md`). The output shows whether they run.

## Likely causes

- The sample service pods are down. See [pod-not-ready.md](pod-not-ready.md).
- The sample service Application is out of sync or was changed by hand. See [argocd-drift.md](argocd-drift.md).
- A network policy blocks the scrape of the admin port. See [network-policy-blocks-service.md](network-policy-blocks-service.md).
- The cluster is new and has not reached Healthy. A new cluster needs about 13 minutes (ADR 0033), and the alert waits 15 minutes.

Other causes are not known from the repository.

## Fix

1. For a service that is down, follow [pod-not-ready.md](pod-not-ready.md) and [argocd-drift.md](argocd-drift.md).
2. For a blocked scrape, follow [network-policy-blocks-service.md](network-policy-blocks-service.md).
3. The repository gives no step to restart the Collector or the metrics agent. Do not edit a Deployment with `kubectl`. Self-heal reverts it.

## Verify

1. Run `monitoring/prometheus/request-rate.promql` again (planned, not run). A `/readyz` series is back.
2. The alert is set to resolve by itself (`time_to_resolve` of 10 minutes in `alerts.tf`).

## Rollback

The fixes in the runbooks named above carry their own rollback. Nothing in this runbook needs to be undone.

## Source

The alert MissingRequestData, ADR 0033, `docs/slos.md`, `helm/sample-service/templates/deployment.yaml` (the readiness probe).

## Status

not exercised
