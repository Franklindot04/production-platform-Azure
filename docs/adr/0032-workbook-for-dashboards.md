# ADR 0032: Define the dashboards as an Azure Monitor workbook

- Status: proposed
- Date: 2026-11-14
- Issue: #40

## Context

ADR 0019 says there is no Grafana and that dashboards are saved queries stored under `monitoring/` and run in the Azure portal. The three KQL files are saved searches on `pp-dev-law` (ADR 0031). The six PromQL files in `monitoring/prometheus` are run by hand in the Prometheus explorer of `pp-dev-amw`. Issue #40 asks for dashboards as code. This ADR changes only the dashboards line of ADR 0019.

## Decision

The workbook is defined in `workbook.tf`. Each chart and table is one query item. It is applied with the persistent layer.

- One Azure Monitor workbook, defined in Terraform in the persistent layer, in `infrastructure/environments/dev/persistent/workbook.tf`, with the azurerm resource `azurerm_application_insights_workbook`.
- Terraform reads the query text from the files in `monitoring/`, so each query exists in one place.
- The six PromQL files become time charts on the Azure Monitor workspace `pp-dev-amw`.
- `failed-requests.kql` and `slow-requests.kql` become tables on the Log Analytics workspace `pp-dev-law`.
- `trace-by-operation.kql` is not in the workbook, because it needs an operation id typed in. It stays a saved search (ADR 0031).
- The workspace ids come from the Terraform resources, so no id is committed.

What stays from ADR 0019: no Grafana, and queries as files under `monitoring/`. What stays from ADR 0031: the three saved searches.

## Consequences

1. A workbook can run a PromQL query against `pp-dev-amw` with the Prometheus data source and the query type `query_range`. The latency SLI query ran this way and a time chart drew it.
2. Microsoft documents the Prometheus query in workbooks as a preview feature.
3. The range sets the resolution. A range of 24 hours returns one point every 30 minutes, so a short incident can fall between two points. A shorter range shows it.
4. A NaN value (no requests in the window) is drawn as 0 on the time chart, so a 0 on the chart can also mean no requests in the window.
5. Prometheus data stays in the Azure Monitor workspace for 18 months (Microsoft documentation), so the workbook can show data from earlier sessions while the cluster is destroyed.
6. The portal lists the workbook in the Workbooks gallery of the Azure Monitor workspace when the "Use Workbooks Preview" switch is off. With the switch on, it is not listed.
7. Checked in the portal after the apply: opened from the Azure Monitor workspace `pp-dev-amw`, under Workbooks, with the "Use Workbooks Preview" switch off, all 8 sections load. None shows an "unsupported" warning or an error box.
   - Request rate, Availability SLI, Error ratio, Latency SLI and Latency p95 draw time charts. Slow requests draws a table. The portal limits the table to the first 250 rows.
   - Abandoned requests and Failed requests show "The query returned no results." in the 24 hour range.
   - A section shows no result when its query returns no series in the 24 hour range. Each item uses a fixed range of 24 hours.
   - `availability-sli` and `error-ratio` divide the rate of series with a 5xx code by the rate of all `/work` series. The numerator falls back to 0 when no 5xx series exists, so with requests and no 5xx series they return 1 and 0, and with no requests they return no data. `abandoned-requests` takes the rate of series with code 499. When the range holds no series with that code, the numerator is empty and the query returns no result.
   - Availability SLI draws 1 where requests arrive and no 5xx series exists. Error ratio draws 0 in the same case.
   - The Availability SLI line drops to 0 at the times the request rate is 0, the same way the Latency SLI line does. A point with no requests in its window is drawn as 0.

## Alternatives considered

- Azure Managed Grafana. Rejected in ADR 0019.
- Saved queries only. This gives no chart, and the PromQL runs by hand.
- A workbook made in the portal and not kept in the repository. It is not code.
