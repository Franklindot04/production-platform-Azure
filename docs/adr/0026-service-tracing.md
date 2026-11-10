# ADR 0026: Trace the sample service with the OpenTelemetry SDK

- Status: proposed
- Date: 2026-11-08
- Issue: #39

## Context

ADR 0019 chose traces from the sample service through an OpenTelemetry Collector to Application Insights. ADR 0025 changed the Collector to the contrib image with the `azure_monitor` exporter and a connection string. The Collector runs in the namespace `observability` and accepts OTLP on 4317 (gRPC) and 4318 (HTTP) at `opentelemetry-collector.observability.svc.cluster.local`. The network policies already allow egress from `apps` to the Collector on both ports. The service is written in Go (ADR 0014), and the Azure Monitor distro does not list Go (ADR 0019). The metrics wrapper `instrument` counts `/healthz`, `/readyz` and `/work` (ADR 0023).

## Decision

- The service uses the OpenTelemetry Go SDK with the `otlptracehttp` exporter and a batch span processor. Modules: `go.opentelemetry.io/otel`, `otel/sdk`, `otel/trace` and `otel/exporters/otlp/otlptrace/otlptracehttp`, all v1.47.0.
- Tracing is off when `OTEL_EXPORTER_OTLP_ENDPOINT` is unset. Nothing is installed and the shutdown function does nothing. When it is set, the exporter sends to `<endpoint>/v1/traces`.
- `service.name` comes from `OTEL_SERVICE_NAME` and defaults to `sample-service`. The chart sets it to the release name.
- An incoming W3C `traceparent` header becomes the parent of the span.
- Only `GET /work` creates a span, one server span per request. `/healthz` and `/readyz` are not traced, because kubelet probes would fill the trace backend. Metrics keep counting all three routes.
- The span name is the fixed route. Attributes are `http.request.method`, `http.route` and `http.response.status_code`. A status of 500 or more marks the span as an error. A request that the client abandons before the response is recorded with status 499 and is not marked as an error.
- The sampler is the SDK default, which is parent-based and samples every root span. Sampling is not reduced for now.
- The chart has `tracing.enabled` (default false) and `tracing.endpoint`. Rendering fails if it is enabled and the endpoint is empty. The `dev` values enable it with the endpoint `http://opentelemetry-collector.observability.svc.cluster.local:4318`.
- The span is flushed on graceful stop, with a 5 second timeout.

## Consequences

- The service now has module dependencies and a `go.sum`. The Dockerfile copies `go.sum` and runs `go mod download` before the build.
- The change takes effect after the next image publish and tag bump (ADR 0018). Until then the running image has no tracing, even though the `dev` values enable it.
- Session 1 showed that server spans of the service reach Application Insights through the Collector and appear in the `AppRequests` table.
- With the default sampler every `/work` request is exported. Cost and volume are not estimated.
- If the Collector is down, the exporter drops spans after its retries. The service keeps answering requests.

## Alternatives considered

- The gRPC exporter. It adds the gRPC module to the binary, and the HTTP exporter is enough for the Collector's 4318 port.
- Auto-instrumentation. It is not available for a Go binary without a build or agent change.
- No tracing in the service. Traces would have nothing to show, and the SLO work could not follow a request through the service.
