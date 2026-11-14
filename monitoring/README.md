# Monitoring queries

Saved queries for the metrics and traces of the sample service. There is no Grafana (ADR 0019). Each file holds one query. The decisions are in ADR 0027 and ADR 0031.

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

These portal steps were run for the queries named under Status. The other queries have not been run by hand.

`prometheus/latency-sli.promql` returns no chart over a range that includes minutes with no traffic. Set the range to minutes with traffic.

In the workbook, the Latency SLI and Availability SLI sections draw a chart over their fixed range of 24 hours. A point with no requests in its window is drawn as 0 there (ADR 0032).

The three KQL queries are saved searches on `pp-dev-law` with the category `Sample service`. `az monitor log-analytics workspace saved-search list` lists them.

## Status

The three KQL files are read by Terraform and defined as saved searches in `infrastructure/environments/dev/persistent/saved-searches.tf` (ADR 0031). They are applied. The workbook is applied (see Workbook). The six PromQL files can still be run by hand in the Prometheus explorer.

Session 1 ran `prometheus/request-rate.promql` in the Azure Monitor workspace, and it answered by route. Server spans of the sample service appear in `AppRequests` with the request name `GET /work`. `logs/failed-requests.kql` and `logs/slow-requests.kql` filter on `GET /work`, the request name in `AppRequests`. In Session 2 `logs/failed-requests.kql` returned the 6,001 failed requests, and `logs/slow-requests.kql` returned 0 rows because no latency was injected. In Session 3 `prometheus/latency-sli.promql`, `prometheus/latency-p95.promql` and `prometheus/request-rate.promql` ran in the Azure Monitor workspace, and `logs/slow-requests.kql` returned slow requests. A summary query over the same range counted 12001 slow requests with durations from 800.033 ms to 802.873 ms. The queries not named on this page have not been run in Sessions 1 to 3. Treat them as unverified.

## Workbook

The workbook is defined in `infrastructure/environments/dev/persistent/workbook.tf` (ADR 0032) and applied with the persistent layer. Each chart and table is one query item. The six PromQL files become time charts on the Azure Monitor workspace. `logs/failed-requests.kql` and `logs/slow-requests.kql` become tables on the Log Analytics workspace.

The portal lists the workbook in the Workbooks gallery of the Azure Monitor workspace when the "Use Workbooks Preview" switch is off. With the switch on, it is not listed.

Opened from the Azure Monitor workspace `pp-dev-amw`, under Workbooks, with the switch off, all 8 sections load. None shows an "unsupported" warning or an error box.

- Request rate, Availability SLI, Error ratio, Latency SLI and Latency p95 draw time charts.
- Slow requests draws a table. The portal limits the table to the first 250 rows.
- Abandoned requests and Failed requests show "The query returned no results." in the 24 hour range.

A section shows no result when its query returns no series in the 24 hour range. Each item uses a fixed range of 24 hours.

`availability-sli` and `error-ratio` divide the rate of series with a 5xx code by the rate of all `/work` series. The numerator falls back to 0 when no 5xx series exists, so with requests and no 5xx series they return 1 and 0, and with no requests they return no data. `abandoned-requests` takes the rate of series with code 499. When the range holds no series with that code, the numerator is empty and the query returns no result.

In the workbook, Availability SLI draws 1 where requests arrive and no 5xx series exists. Error ratio draws 0 in the same case. The Availability SLI line drops to 0 at the times the request rate is 0, the same way the Latency SLI line does.

`logs/trace-by-operation.kql` is not in the workbook, because it needs an operation id typed in.

The time charts draw a NaN value (no requests in the window) as 0. A range of 24 hours returns one point every 30 minutes.

## Not built

- Alerts for missing data (planned, #136).

The alert rules are defined in `infrastructure/environments/dev/persistent/alerts.tf` (ADR 0028, `docs/slos.md`). They exist in Azure only after the persistent layer is applied.
