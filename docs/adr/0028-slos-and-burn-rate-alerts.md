# ADR 0028: Set SLOs for the sample service and alert on burn rate

- Status: proposed
- Date: 2026-11-08
- Issue: #41

## Context

The sample service exports `http_requests_total` and `http_request_duration_seconds` to the Azure Monitor workspace (ADR 0023, ADR 0024). Queries are kept as files under `monitoring/` (ADR 0027). The persistent layer already has the Azure Monitor workspace and the action group (ADR 0022). Session 2 experiment 3 injects errors and latency and expects a burn-rate alert to fire and an email to arrive. A live session lasts about two hours.

## Decision

- The SLO window is 30 days.
- Availability SLI: the share of `/work` requests whose code is not 5xx, among all `/work` requests. Code 499 is not an error. Target 99%, error budget 0.01.
- Latency SLI: the share of `/work` requests that finish within 0.5 seconds, from the histogram. Target 95%, error budget 0.05.
- Four alerts in one Prometheus rule group, `pp-dev-slo-alerts`, defined in `infrastructure/environments/dev/persistent/alerts.tf`. Each needs both of its windows over the threshold.
  1. Availability fast burn: error ratio above 0.144 (14.4 x 0.01) over 15m and 5m, for 2 minutes, severity 1.
  2. Availability slow burn: error ratio above 0.06 (6 x 0.01) over 1h and 15m, for 5 minutes, severity 2.
  3. Latency fast burn: slow-request ratio above 0.72 (14.4 x 0.05) over 15m and 5m, for 2 minutes, severity 1.
  4. Latency slow burn: slow-request ratio above 0.30 (6 x 0.05) over 1h and 15m, for 5 minutes, severity 2.
- The windows are shorter than the usual 1h/5m and 6h/30m, because a live session lasts about two hours. The long windows would not fill in that time.
- The thresholds are literal numbers in the expressions, with the arithmetic in a comment. Terraform does not compute them.
- There are no recording rules. Each alert expression is self-contained.
- Each alert sends to `azurerm_monitor_action_group.main`.
- There is no alert for missing data in this change. A service that is down and receives no requests produces no data and no alert. An alert for missing data is planned (#136).

## Consequences

- With short windows, a short burst can cross the fast-burn threshold. The alerts suit a session, and the windows may need to change for a longer run.
- No data means no alert, until the alert for missing data (#136) is built.
- The alerts are applied. The availability alerts fired and sent mail in Session 2 experiment 3. The latency alerts are untested.
- The rule group is part of the persistent layer and is applied.
- The cost of the rule group and the alert notifications is not estimated.

## Alternatives considered

- The usual 1h/5m and 6h/30m windows. They do not fit a two hour session.
- Recording rules. They add a second place to read and change, and the expressions are short enough to repeat.
- Scheduled query alerts on logs. The SLIs come from metrics, and the metrics are already in the Azure Monitor workspace.
- Grafana alerting. Ruled out by ADR 0019.
