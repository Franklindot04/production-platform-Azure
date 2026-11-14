# ADR 0027: Keep dashboard queries as files under monitoring/

- Status: proposed
- Date: 2026-11-08
- Issue: #40

## Context

ADR 0019 ruled out Grafana and said dashboards are saved queries on the workspaces, stored under `monitoring/`. Metrics are in the Azure Monitor workspace `pp-dev-amw` and are queried with PromQL. Traces are in Application Insights, which is linked to the Log Analytics workspace `pp-dev-law`, and are queried with KQL. The Azure Monitor workspace has no saved-query resource for PromQL. KQL has saved searches on the Log Analytics workspace.

## Decision

- Queries are kept as files under `monitoring/prometheus` (PromQL) and `monitoring/logs` (KQL). Each file holds one query and starts with a comment header that says what it shows, where to run it and what it reads.
- The queries are run by hand in the portal. Terraform and GitOps do not deploy the PromQL queries. ADR 0031 changes this for the three KQL queries: it deploys them as saved searches.
- `monitoring/README.md` lists the files and where each one runs.

## Consequences

- Queries are reviewed in pull requests.
- Nobody opens a dashboard. A query has to be copied into the portal to run it.
- Session 1 ran `prometheus/request-rate.promql` in the Azure Monitor workspace, and it answered by route. Server spans of the sample service appear in `AppRequests` with the request name `GET /work`. `logs/failed-requests.kql` and `logs/slow-requests.kql` filter on `GET /work`, the request name in `AppRequests`. In Session 2 `logs/failed-requests.kql` returned the 6,001 failed requests, and `logs/slow-requests.kql` returned 0 rows because no latency was injected. In Session 3 `prometheus/latency-sli.promql`, `prometheus/latency-p95.promql` and `prometheus/request-rate.promql` ran in the Azure Monitor workspace, and `logs/slow-requests.kql` returned slow requests. A summary query over the same range counted 12001 slow requests with durations from 800.033 ms to 802.873 ms. The queries not named here have not been run in Sessions 1 to 3.
- ADR 0031 defines the KQL files as saved searches in the persistent layer. They are applied.
- Alert rules and SLO queries are not part of this decision (issue #41).

## Alternatives considered

- Grafana. Ruled out by ADR 0019.
- KQL saved searches through Terraform. Chosen for the KQL files in ADR 0031.
- Azure workbooks. Chosen for the dashboards in ADR 0032.
