# Monitoring queries

Saved queries for the metrics and traces of the sample service. There is no Grafana (ADR 0019). Each file holds one query. The decision is in ADR 0027.

## Files

| File | Language | Shows |
|---|---|---|
| `prometheus/request-rate.promql` | PromQL | Requests per second by route |
| `prometheus/error-ratio.promql` | PromQL | Share of `/work` requests with a 5xx code. Code 499 is not an error |
| `prometheus/latency-p95.promql` | PromQL | 95th percentile latency of `/work` |
| `prometheus/abandoned-requests.promql` | PromQL | Rate of `/work` requests with code 499 |
| `prometheus/availability-sli.promql` | PromQL | Availability SLI: share of `/work` requests without a 5xx code |
| `prometheus/latency-sli.promql` | PromQL | Latency SLI: share of `/work` requests within 0.5 seconds |
| `logs/failed-requests.kql` | KQL | Failed `/work` requests, newest first |
| `logs/slow-requests.kql` | KQL | `/work` requests slower than a threshold set at the top of the file |
| `logs/trace-by-operation.kql` | KQL | All rows of one operation id from `AppRequests` and `AppDependencies` |

The PromQL files read the metrics of the sample service (`http_requests_total` and `http_request_duration_seconds`). Their names are defined in `applications/sample-service/metrics.go`.

## Where each file runs

- PromQL: the Prometheus explorer of the Azure Monitor workspace `pp-dev-amw` in the Azure portal.
- KQL: the Logs view of the Log Analytics workspace `pp-dev-law`, or of Application Insights.

## How to run one

1. Open the file and copy the query. Lines that start with `#` (PromQL) or `//` (KQL) are comments.
2. Open the matching view in the portal.
3. Paste the query and run it.
4. For `slow-requests.kql`, set `thresholdMs` first. For `trace-by-operation.kql`, replace the value of `operationId` with an operation id taken from `failed-requests.kql` or `slow-requests.kql`.

These portal steps are not verified.

## Status

Nothing in this directory is deployed by Terraform or GitOps. The queries are run by hand.

The queries have not been run against any workspace. The assumption that `/work` server spans arrive in `AppRequests` is not verified either. Session 1 runs `prometheus/request-rate.promql` and `logs/failed-requests.kql`. Until then, treat every file here as unverified.

## Not built

- Queries deployed as saved searches (planned).
- Alerts for missing data (planned).

The alert rules are defined in `infrastructure/environments/dev/persistent/alerts.tf` (ADR 0028, `docs/slos.md`). They exist in Azure only after the persistent layer is applied.
