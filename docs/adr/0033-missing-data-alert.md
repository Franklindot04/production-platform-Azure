# ADR 0033: Alert on missing request data in the session layer

- Status: proposed
- Issue: #136

## Context

ADR 0028 sets four burn-rate alerts and leaves out an alert for missing data. A service that is down and receives no requests produces no data, and no burn-rate alert fires. The burn-rate rule group is in the persistent layer (`infrastructure/environments/dev/persistent/alerts.tf`). The cluster exists only during a live session (ADR 0009).

## Decision

1. The alert is a Prometheus rule group in the session layer, in `infrastructure/environments/dev/session/alerts.tf`. It exists only while the cluster exists, so it cannot fire between sessions. It looks the Azure Monitor workspace up with a data source, as `monitoring.tf` of the session root does.
2. One rule, `MissingRequestData`, severity 2, enabled, with the expression `absent_over_time(http_requests_total{route="/readyz"}[5m])`. The probes call `/readyz`, so the series exists whenever a pod runs, with or without `/work` traffic.
3. The wait (`for`) is 15 minutes (`PT15M`). A new cluster needs about 13 minutes to reach Healthy (772 seconds in Session 2), so a shorter wait fires at the start of every session.
4. The mail goes through the existing action group `pp-dev-alerts` of the persistent layer, looked up with a data source.

What stays from ADR 0028: the four burn-rate alerts, their thresholds and their rule group in the persistent layer.

## Consequences

1. The alert exists only while the cluster exists. It cannot detect an outage between sessions, because no cluster runs then.
2. The 15 minute wait delays the alert for a real outage by the same time.
3. The rule group is applied by `session.sh up --apply`, not by an apply of the persistent layer. It is destroyed with the session layer.
4. The alert is written. It is not yet applied or exercised. Session 4 exercises it (planned).

## Alternatives considered

- A rule in the persistent rule group. It would fire whenever no cluster exists.
- A shorter wait. It would fire at the start of every session, while the cluster is still starting.
