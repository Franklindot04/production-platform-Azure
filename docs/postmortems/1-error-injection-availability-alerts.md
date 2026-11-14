# Postmortem: planned error injection and the availability alerts

Level: 1
Session: Session 2 ([results](../sessions/session-2-results.md))

This postmortem is blameless. It uses the time since the fault was set (T+0), with no calendar date and no clock time.

## Summary

The error rate of both sample service pods was set to 1 on purpose, to test the availability alerts. All `/work` requests failed for 10 minutes. Both availability alerts sent mail, and the failure ended when the error rate was set back to 0.

## Impact

All `/work` requests failed for 10 minutes: 6,001 of 6,001 requests at 10 requests per second. The load test (k6) exited 99 because its thresholds were crossed. The failure was a planned test.

## Detection

The AvailabilityFastBurn alert (severity 1) sent its email about 4 min 40 s after the fault was set. The AvailabilitySlowBurn alert (severity 2) sent its email about 13 min 45 s after.

## Timeline

Times are counted from the moment the fault was set (T+0).

| Time | Event |
|---|---|
| T+0:00 | The error rate is set to 1 on both pods through `PUT /admin/config` on the admin port. The load test starts at 10 requests per second |
| T+4:40 | The AvailabilityFastBurn email arrives |
| T+10:00 | The load test ends. The error rate is set back to 0 on both pods |
| T+13:45 | The AvailabilitySlowBurn email arrives |
| About T+25:00 | The fast burn alert resolves, about 15 minutes after the recovery |
| About T+35:00 | The slow burn alert resolves, about 25 minutes after the recovery |

## Cause

The error rate was set to 1 through the admin port on both pods. This was a planned test (Session 2 experiment 3).

## What went well

- Both alerts fired and sent mail.
- `monitoring/logs/failed-requests.kql` found the failures: 6,001 rows, all `GET /work` with status 500, equal to the failed requests of the load run.
- The setting needs no rollout. Setting the error rate back to 0 ended the failure.

## What went wrong

- The alerts resolved about 15 minutes (fast) and about 25 minutes (slow) after the recovery. This follows the long window of each alert.
- The latency path and `monitoring/logs/slow-requests.kql` were not exercised. No latency was injected.
- The admin port setting applies to one pod only, so both pods must be set. A setting on one pod changes only part of the traffic.

## Runbook

[availability-burn.md](../runbooks/availability-burn.md) was used. The `PUT` in its Fix section and `failed-requests.kql` were run. `GET /admin/config` from its First checks was not run. Its Status line changes from `not exercised` to `exercised in Session 2`. The alert thresholds are in [slos.md](../slos.md).

## Actions

1. Exercise the latency path and `slow-requests.kql` with injected latency (done in Session 3, [results](../sessions/session-3-results.md)).
2. Decide whether the delay before an alert resolves needs a change (planned, no issue yet).
