# Live session 3: latency alerts

Status: planned. Issue #41.

Goal: slow both pods of the sample service under steady load, see LatencyFastBurn and LatencySlowBurn fire, send mail and resolve, run `monitoring/logs/slow-requests.kql` against real slow requests, follow the [latency-burn runbook](../runbooks/latency-burn.md), and destroy everything.

Time box: teardown starts one hour after the load starts, whatever is unfinished.

Rules are the same as in [Session 1](session-1.md) ([results](session-1-results.md)) and [Session 2](session-2.md) ([results](session-2-results.md)): approved plans, masked output, no stored credentials.

## Before the session

1. This plan and the corrected latency-burn runbook are merged.
2. k6 is installed on the maintainer's machine.
3. `./infrastructure/session.sh check` exits 0 and vCPU use is 0 of 4.
4. The persistent layer is applied: the rule group `pp-dev-slo-alerts` and the action group exist.

## Run sheet

L is the moment the sample service is healthy after the bootstrap. Times after L are in minutes.

| Time | Step | Command or action | Record |
|---|---|---|---|
| Before L | Preflight and rebuild | The same commands as Session 2: `./infrastructure/session.sh check`, then `./infrastructure/session.sh up --apply` after the plan is approved, then `./infrastructure/session.sh bootstrap` | The rebuild time |
| L+0 | Start load | `SCENARIO=baseline RATE=10 DURATION=60m BASE_URL=http://<ingress address> k6 run --summary-export=<file> tests/load/sample-service.js`, left running | The start time |
| L+0 to L+15 | Baseline | Run `monitoring/prometheus/latency-sli.promql`, `latency-p95.promql` and `request-rate.promql` in the Prometheus explorer of the Azure Monitor workspace `pp-dev-amw` | The result of each. This is the first run of `latency-sli.promql` and `latency-p95.promql` |
| L+15 | Inject | On each of the two pods: `kubectl port-forward -n apps pod/<pod name> 8081:8081`, then `curl -X PUT http://localhost:8081/admin/config -d '{"latency":"800ms"}'` | The time, and the config echoed by each pod |
| L+15 to L+35 | Watch | The alerts in Azure Monitor and the mail from the action group. Follow the First checks of [latency-burn.md](../runbooks/latency-burn.md) | When each alert fired, when each mail arrived, and where the runbook steps did not match what was seen |
| L+35 | Set back | The same `curl` with `{"latency":"0s"}` on each pod, through a port-forward to that pod (Fix step 1 of the runbook) | The time, and the echoed config |
| After L+35 | Log query | `monitoring/logs/slow-requests.kql` in the Logs view of `pp-dev-law`, with `thresholdMs` 500. Run it again until rows appear | The rows returned, compared with the requests k6 sent while the latency was set, and the time the rows first appeared |
| L+35 to L+60 | Recovery | Run `latency-sli.promql` and `latency-p95.promql` again (Verify steps of the runbook) | The values, and when each alert resolved |
| L+60 | Wrap up | k6 ends. Save the output and mask the address | Files saved |
| L+60 | Teardown | `./infrastructure/session.sh down`, then `down --yes`, then `./infrastructure/session.sh check`. `down --yes` repeats once after a wait if the destroy stops (#89) | The output of `check`. Whether the repeat ran |

## Calculated timings

These timings are calculated from the alert expressions in `infrastructure/environments/dev/persistent/alerts.tf`. They are not observed.

Assumptions:

1. The load is a steady 10 requests per second.
2. Every request is slow after the injection.
3. There are 15 minutes of healthy traffic before the injection.
4. The rule group evaluates every minute (`interval` is `PT1M`). The calculation uses continuous time.

In the arithmetic, t is the number of minutes since the injection, and the share is the share of requests slower than 0.5 seconds in the window.

**LatencySlowBurn** (threshold 0.30, windows 1h and 15m, for 5 minutes):

- The 15 minute window passes 0.30 when t / 15 > 0.30, which is t > 4.5. The window passes 0.30 after 4.5 minutes of slow traffic.
- The 1 hour window holds the 15 healthy minutes and the slow minutes. It passes 0.30 when t / (15 + t) > 0.30, which is t > 0.30 x 15 / 0.70 = 6.4. The window passes 0.30 after 6.4 minutes.
- Both windows are over the threshold from minute 6.4. The alert fires after the 5 minute "for": 6.4 + 5 = 11.4 minutes after the injection.

**LatencyFastBurn** (threshold 0.72, windows 15m and 5m, for 2 minutes):

- The 5 minute window passes 0.72 when t / 5 > 0.72, which is t > 3.6. The window passes 0.72 after 3.6 minutes.
- The 15 minute window passes 0.72 when t / 15 > 0.72, which is t > 10.8. The window passes 0.72 after 10.8 minutes.
- Both windows are over the threshold from minute 10.8. The alert fires after the 2 minute "for": 10.8 + 2 = 12.8 minutes after the injection.

So LatencySlowBurn is calculated to fire before LatencyFastBurn in this session, because the cluster holds less than an hour of healthy traffic.

- The delay between the condition and the mail is not calculated. Session 2 recorded the time from the fault to the mail for AvailabilityFastBurn in [Session 2 results](session-2-results.md). The plan does not assume a delay.
- How long resolution takes is not calculated. It is recorded. The rules set `time_to_resolve` to 10 minutes.

## What is recorded

1. The rebuild time.
2. The results of `latency-sli.promql`, `latency-p95.promql` and `request-rate.promql` at baseline.
3. The time the latency was set, when each alert fired and sent mail, the time it was set back, and when each alert resolved.
4. The rows of `slow-requests.kql` against the requests k6 sent, and when the rows first appeared.
5. Where the latency-burn runbook steps did not match what was seen.
6. Anything done by hand.
7. Whether the destroy repeat ran (#89).

## Not in this session

- The alert for missing data (planned, a separate change).
- The six other runbooks, the node drain (#98) and the destroy repeat test (v0.3.0 in [docs/plan.md](../plan.md)).

## After the session

1. `session.sh check` exits 0.
2. The results go into `docs/sessions/session-3-results.md` in a pull request.
3. The status of `latency-burn.md` is set to what was run.
4. #41 closes after both latency alerts were seen firing.
5. A release is created only when the maintainer says.
