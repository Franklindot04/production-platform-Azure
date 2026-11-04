# ADR 0008: Choose the metrics and dashboard stack

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

SLOs need metric history. The cluster is destroyed after each session, so anything stored inside the cluster is lost with it. The README lists Azure Monitor, Prometheus, Grafana and OpenTelemetry, and the roles of each are not defined yet.

## Decision

- Metrics: Prometheus format. Send them to an Azure Monitor workspace using Azure Monitor managed service for Prometheus. The workspace is in the persistent layer, so metric history survives cluster teardown.
- Logs: Log Analytics workspace, also in the persistent layer.
- Traces: OpenTelemetry instrumentation in the sample service, sent through an OpenTelemetry Collector in the cluster. The trace backend is not chosen. It is an open question in the architecture document.
- Dashboards: Grafana, with dashboards stored as code in `monitoring/`. Whether this is Azure Managed Grafana or Grafana in the cluster is not decided. Azure Managed Grafana is a separate paid service, and Grafana in the cluster is lost on teardown unless dashboards are provisioned from code. The choice is made in the Epic 5 (#5) issues.
- Alerts: Azure Monitor alert rules that notify an action group, with email as the first target. This is an assumption.

## Consequences

- Metric history outlives each cluster, which SLO reporting needs.
- Ingestion and retention costs apply to the workspaces. Amounts are not estimated here.
- An SLO window is only meaningful while the service is running. Because the cluster is down between sessions, SLOs are measured over session time, with generated traffic. The architecture document says this.

## Alternatives considered

- Self-hosted Prometheus in the cluster. No Azure ingestion cost, but history is lost on teardown unless it is written to persistent storage or remote storage.
- Azure Monitor only, without Prometheus. Less portable, and does not match the planned tool list.
