# ADR 0019: Choose the trace backend and Grafana hosting

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

ADR 0008 left the trace backend and the Grafana hosting open. Anything stored in the cluster is lost when the session ends, and the capacity for workloads is small (ADR 0012). The maintainer ruled out a paid managed Grafana and cluster-wide log collection.

Facts read from the Azure Monitor documentation:

- The Azure Monitor OpenTelemetry distro is documented for .NET, Node.js, Python and Java. Go is not named.
- For other languages, the documented path is an application instrumented with an OpenTelemetry SDK that sends OTLP through an OpenTelemetry Collector to Azure Monitor. That path is generally available. It uses the `otlphttp` exporter with the `azure_auth` extension and needs Collector 0.132.0 or later. Support for these components comes from the community.
- Application Insights is workspace-based. A classic resource is retired, and data is billed through the Log Analytics workspace.
- An Application Insights resource can be created with OTLP support, which gives endpoints for each signal. Whether that option is generally available is not stated.
- The AKS-integrated OTLP onboarding is in preview.

## Decision

- Traces: a workspace-based Application Insights resource in the persistent layer, linked to the Log Analytics workspace. The Go service sends OTLP to an OpenTelemetry Collector in the cluster, and the Collector sends it to Azure Monitor with the `otlphttp` exporter.
- The Collector authenticates with workload identity (issue #42). No credential is stored. ADR 0025 changes the Collector authentication.
- Metrics: managed Prometheus into the Azure Monitor workspace (ADR 0008).
- Dashboards: no Grafana. Dashboards are saved queries on the workspaces, stored under `monitoring/` and run in the Azure portal. ADR 0032 replaces this line: the dashboards are an Azure Monitor workbook.
- Logs: no cluster-wide log collection. Logs are read with `kubectl logs`.

## Consequences

- Traces and metrics outlive the cluster, because they are stored in the persistent layer.
- The Collector's Azure Monitor path is community supported, and it depends on workload identity working.
- Queries in the portal are less convenient than Grafana dashboards.
- Ingestion and retention costs are not estimated.
- If the Collector path fails in Session 1, traces are cut for that session and recorded. No trace backend is installed in the cluster.

## Alternatives considered

- Azure Managed Grafana. A paid service. Ruled out.
- Grafana in the cluster. It uses capacity that is not available, and it is lost on teardown.
- Jaeger or Tempo in the cluster. Same reasons.
- The Azure Monitor distro. It does not list Go.
- The AKS-integrated OTLP onboarding. In preview.
