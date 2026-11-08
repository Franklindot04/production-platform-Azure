# ADR 0025: Send traces with the Azure Monitor exporter and a connection string

- Status: proposed
- Date: 2026-11-08
- Issue: #39

## Context

ADR 0019 chose a workspace-based Application Insights resource for traces and an OpenTelemetry Collector that sends OTLP to it, authenticated with workload identity. This ADR supersedes only the Collector authentication part of ADR 0019.

Facts read from the upstream releases and documentation:

- The contrib release v0.165.0 lists `azuremonitorexporter` in its distribution manifest.
- The exporter README gives beta stability for traces, metrics and logs. It accepts `connection_string`. The environment variable `APPLICATIONINSIGHTS_CONNECTION_STRING` overrides the configuration. The README names the exporter `azure_monitor` in its examples.
- The OTLP route in ADR 0019 needs an Application Insights resource with OTLP support. Microsoft documents creating one only in the portal or from an ARM template. The route also needs workload identity and a Collector 0.148.0 or later.

## Decision

- The Collector runs the contrib image `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib` at 0.165.0, from the chart `opentelemetry-collector` 0.178.2. Argo CD installs it from `gitops/dev/apps/opentelemetry-collector.yaml`, with the values in `gitops/dev/values/opentelemetry-collector.yaml`.
- It exports traces to the existing Application Insights resource with the `azure_monitor` exporter. There is one traces pipeline: OTLP receiver, `memory_limiter` and `batch`.
- The connection string is read at run time by `session.sh bootstrap secrets` from the output `application_insights_connection_string` of the persistent root. The script creates the cluster secret `appinsights-connection` in the namespace `observability`. The Collector reads it through an environment variable.
- The connection string is never written to Git, a file, a plan or a pull request. The script passes it through pipes only.

What stays from ADR 0019: Application Insights in the persistent layer, no Grafana, no cluster-wide log collection.

## Consequences

- The exporter is beta. Not checked on AKS.
- The chart was written for appVersion 0.163.2 and runs with a newer image. Not checked on AKS.
- The connection string is in a cluster secret, which anyone with cluster admin can read. It is also in the Terraform state, which is in the private state container.
- The instrumentation key in the connection string can be used to send telemetry to the resource.
- Traces need no workload identity. The Key Vault and metrics work is not affected.
- The Collector does not start until the secret exists. Not checked on AKS.
- The secrets part does not run on `kind`, which has no Azure state. A full bootstrap on `kind` skips it.

## Alternatives considered

- The OTLP route of ADR 0019. The resource can be created only in the portal or from a template, and the route needs workload identity and a newer Collector.
- The Azure Monitor distro. It does not list Go.
- Skip the Azure export in Session 1. No traces would reach the workspace.
