# ADR 0023: Serve metrics on the admin port

- Status: proposed
- Date: 2026-11-06
- Issue: #38

## Context

ADR 0008 sends Prometheus metrics to an Azure Monitor workspace through managed Prometheus. The sample service (ADR 0014) needs to expose request counts and latency for the SLIs. The service uses only the Go standard library and has no `go.sum`. The admin port is not part of the Kubernetes Service, and the ingress cannot reach it.

## Decision

- The service writes the Prometheus text format (version 0.0.4) itself, with the standard library. It keeps one counter, `http_requests_total` with the labels `route` and `code`, and one histogram, `http_request_duration_seconds` with the label `route`.
- `GET /metrics` is served on the admin port only. The API handler does not serve it.
- The route label is a fixed string set where each handler is registered. It is not taken from the request URL.
- The managed Prometheus agent scrapes the pods directly through a PodMonitor on the `admin` container port. The Service and the ingress never carry `/metrics`.
- The PodMonitor is in the Helm chart and is off by default (`metrics.scrape.enabled`). The network policy `allow-metrics-scrape` lets pods labelled `rsName: ama-metrics` in `kube-system` reach port 8081.

## Consequences

- No new dependency, no `go.sum` and no Dockerfile change.
- The service has no Go runtime or process metrics by default.
- The text format is maintained in this repository, and the tests cover its output.
- The scrape rule and the pod label come from the add-on documentation. They are not checked on AKS.
- The PodMonitor has not been applied to any cluster. It needs the custom resource definition from the managed Prometheus add-on, which is not enabled yet.

## Alternatives considered

- A Prometheus client library. It adds a dependency and a `go.sum`, and the Dockerfile would change.
- `/metrics` on the API port. The ingress could reach it.
- A ServiceMonitor. It needs the admin port on the Service, which the Service does not expose.
