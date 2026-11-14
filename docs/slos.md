# Service level objectives

SLOs for `/work` of the sample service. The decision is in ADR 0028. The window is 30 days.

## SLIs

| SLI | Definition | Query |
|---|---|---|
| Availability | Share of `/work` requests whose code is not 5xx, among all `/work` requests. Code 499 (client abandoned the request) is not an error | `monitoring/prometheus/availability-sli.promql` |
| Latency | Share of `/work` requests that finish within 0.5 seconds, from the histogram `http_request_duration_seconds` | `monitoring/prometheus/latency-sli.promql` |

The error ratio is in `monitoring/prometheus/error-ratio.promql`. The queries show a 5 minute window. They have not been run against metric data.

## SLOs and error budget

| SLO | Target | Error budget |
|---|---|---|
| Availability | 99% | 0.01 |
| Latency | 95% | 0.05 |

The budget is the share of requests allowed to miss the SLI over 30 days. A burn rate of 1 uses the budget in exactly 30 days. A burn rate of 14.4 uses it in 30 / 14.4, about 2 days. A burn rate of 6 uses it in 5 days.

## Alerts

The alert is the burn rate times the budget. Each alert needs both of its windows to be over the threshold, for the time in the last column.

| Alert | Windows | Burn rate | Threshold | For | Severity |
|---|---|---|---|---|---|
| AvailabilityFastBurn | 15m and 5m | 14.4 | 0.144 (14.4 x 0.01) | 2 minutes | 1 |
| AvailabilitySlowBurn | 1h and 15m | 6 | 0.06 (6 x 0.01) | 5 minutes | 2 |
| LatencyFastBurn | 15m and 5m | 14.4 | 0.72 (14.4 x 0.05) | 2 minutes | 1 |
| LatencySlowBurn | 1h and 15m | 6 | 0.30 (6 x 0.05) | 5 minutes | 2 |

For the latency alerts the compared value is the share of requests slower than 0.5 seconds.

The four alerts are in one rule group, `pp-dev-slo-alerts`, in `infrastructure/environments/dev/persistent/alerts.tf`. Each alert sends to the action group `pp-dev-alerts`. The address of the action group is set at run time and is not in the repository.

The rule group is part of the persistent layer and is applied.

## Limits

- The windows are shorter than the usual 1h/5m and 6h/30m, because a live session lasts about two hours.
- A service that is down and receives no requests produces no data, and no alert fires. An alert for missing data is planned.
- The alerts are applied. The availability alerts fired, sent mail and resolved in Session 2 experiment 3. LatencyFastBurn and LatencySlowBurn fired, sent mail and resolved in Session 3.
- Runbooks for the four alerts: [availability-burn](runbooks/availability-burn.md) was exercised in Session 2, and [latency-burn](runbooks/latency-burn.md) was exercised in Session 3: step 7 of the First checks and Fix step 1 ran, and steps 4 to 6 of the First checks did not.
