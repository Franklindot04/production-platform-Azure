# Screenshots

These are portal screenshots of the Azure Monitor alert MissingRequestData and of the "Sample service" workbook in the Azure Monitor workspace `pp-dev-amw`. The images are in `assets/screenshots/`.

Click an image to enlarge it. Press Esc or click again to close it.

## Alert fired

![The Azure Monitor alerts list with one alert, MissingRequestData in the rule group pp-dev-session-alerts, severity 2 - Warning, affected resource pp-dev-amw, alert condition Fired](assets/screenshots/alert-fired.png)

The alerts list shows 1 total alert, counted under Warning. The alert is `pp-dev-session-alerts/MissingR…` (the name is cut off in the list), severity 2 - Warning, on `pp-dev-amw`, with the alert condition Fired and the user response New. See [experiment 5 of the Session 4 results](sessions/session-4-results.md) and the runbook [missing-request-data](runbooks/missing-request-data.md).

## Alert resolved

![The Azure Monitor alerts list with the same alert, MissingRequestData in the rule group pp-dev-session-alerts, with the alert condition Resolved](assets/screenshots/alert-resolved.png)

The same list shows the same alert with the alert condition Resolved and the user response New. See [experiment 5 of the Session 4 results](sessions/session-4-results.md) and the runbook [missing-request-data](runbooks/missing-request-data.md).

## Workbook: request rate and availability SLI

![The Sample service workbook in pp-dev-amw showing the Request rate chart by route and the Availability SLI chart, both over a time range from 6:30 PM to after 8:45 PM](assets/screenshots/workbook-request-rate-availability.png)

The Request rate chart shows requests per second by route, with a summary of 40 for `/work`, 2.4 for `/readyz` and 1.2 for `/healthz`. The `/work` line starts at 10, falls to 0 near 7:25 PM, returns to 10, and falls to 0 again at the right edge. The Availability SLI chart below it, the share of `/work` requests without a 5xx code, has the same shape between 1 and 0, with a summary value of 4. The SLIs are defined in [slos.md](slos.md).

## Workbook: error ratio and latency SLI

![The Sample service workbook in pp-dev-amw showing the Error ratio chart and the Latency SLI chart over a time range from 6:30 PM to after 8:45 PM](assets/screenshots/workbook-error-ratio-latency-sli.png)

The Error ratio chart, the share of `/work` requests with a 5xx code, is flat at 0 over the range, with a summary value of 0. The Latency SLI chart, the share of `/work` requests within 0.5 seconds, starts at 1, falls to 0 near 7:25 PM, returns to 1, and falls to 0 again at the right edge, with a summary value of 4. The SLIs are defined in [slos.md](slos.md).

No Argo CD screenshot is included.
