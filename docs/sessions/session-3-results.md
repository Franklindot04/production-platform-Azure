# Live session 3: latency alerts, results

Results of the run described in [session-3.md](session-3.md). Issue #41.

## Scope

The session created the `dev` session layer, ran the sample service under steady load twice, injected 800 ms of latency on both pods in the second run, watched LatencyFastBurn and LatencySlowBurn fire and resolve, read the latency queries and `slow-requests.kql`, and destroyed the layer. Times of day on this page are the maintainer's local clock. "Injection" means the second pod being set to 800 ms. "Set back" means the second pod being set to 0 s. "L" is the start of the second load run.

## Cluster

| Step | Result |
|---|---|
| `session.sh up --apply` | Added 10 resources and took 13 min 1 s |
| `session.sh bootstrap` | Took 2 min 27 s |
| Argo CD applications | 4 were Synced and Healthy: `cluster-rules`, `opentelemetry-collector`, `root` and `sample-service` |
| Sample service pods | Both were 1/1 Running with 0 restarts |

## Load runs

| Run | Load | Requests | Failed | Average | Median | p90 | p95 | Maximum | Thresholds |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 10 requests a second for 60 min, no latency injected | 36000 | 0 (0.00 percent) | 111.36 ms | 84.69 ms | 107.48 ms | 353.87 ms | 2.72 s | Both passed |
| 2 | The same load, started at L | 36001 | 0 | 376.67 ms | 88.46 ms | 888.13 ms | 895.41 ms | 1.88 s | The p(95)<500 threshold was crossed and k6 reported it. The failed-request threshold passed |

In run 2 the latency was set to 800 ms on both pods through `PUT /admin/config` on port 8081, at 19:57:07 and at 19:57:11. Both calls returned status 200. It was set to 0 s at 20:17:07 and at 20:17:11, and both calls returned status 200. The 800 ms period lasted 20 min.

## Alerts

| Alert | Severity | Fired | Expression value at fire | Resolved | Fired mail | Resolved mail |
|---|---|---|---|---|---|---|
| LatencyFastBurn | Sev1 | 13 min 39 s after the injection | 0.921, against the rule threshold 0.72 | 11 min 39 s after the set back | Reached the inbox at 20:39, against the alert time 20:10:50, after the Resolved mail for the same alert | 9 min after the resolved time |
| LatencySlowBurn | Sev2 | 17 min 37 s after the injection | not recorded | 20 min 38 s after the set back | 2 min after the alert time | 4 min after the resolved time |

Calculated in the [plan](session-3.md): LatencySlowBurn 11.4 min and LatencyFastBurn 12.8 min after the injection, slow burn first. Observed: fast burn 13 min 39 s and slow burn 17 min 37 s, fast burn first. Both alerts fired and both resolved. No cause for the difference in order is established.

## Prometheus explorer readings

Workspace `pp-dev-amw`, range 19:45 to 20:40. Each value is read from the circle on the line at the time shown. The columns are the queries `latency-sli.promql` (the share of `/work` requests within 0.5 s), `latency-p95.promql` (seconds) and `request-rate.promql` (requests a second, by route).

| Time | Phase | latency-sli | latency-p95 (s) | Rate `/work` | Rate `/readyz` | Rate `/healthz` |
|---|---|---|---|---|---|---|
| 19:50 | Before the injection | 1 | 0 | 10 | 0.4 | 0.2 |
| 20:00 | During | 0.42 | 0.96 | 9.97 | 0.4 | 0.2 |
| 20:10 | During | 0 | 0.97 | 10 | 0.4 | 0.2 |
| 20:17 | At the set back | 0.14 | 0.98 | 10 | 0.4 | 0.2 |
| 20:30 | After | 1 | 0 | 10 | 0.4 | 0.2 |

- The request rate on `/work` stayed at 10 a second during the injection.
- `latency-p95` is an estimate inside a histogram bucket. With every request between 0.5 s and 1 s the estimate falls near 0.975 s, so it does not read the injected 800 ms.
- The 0 before and after is a value below the smallest bucket (0.005 s) shown as 0.

## slow-requests.kql

Workspace `pp-dev-law`, range 19:42 to 20:42, threshold 500 ms. The editor lists 1000 rows at most.

- The newest slow row is at 20:17:11, the second of the second set back call.
- The 24 newest rows visible in the result are all `GET /work` with result code 200 and durations from 800.116 ms to 801.058 ms.
- A summary query over the same range returned: total 34145 requests, slow 12001, the first slow request in the second of the first injection call (19:57:07), the last slow request in the second of the second set back call (20:17:11), the shortest slow request 800.033 ms and the longest request 802.873 ms.
- k6 counted 36001 requests in run 2 and the table counts 34145 for the range. The two counts differ by 1856 and are not equated.

## Teardown

| Step | Result |
|---|---|
| `session.sh down` | Planned 0 to add, 0 to change and 10 to destroy |
| `session.sh down --yes` | Destroyed 10 resources |
| `session.sh check` | Exited 0 and listed none for the session layer groups, compute, public IP addresses, load balancers, managed disks and unexpected resource groups |

## Reading notes

- The first `kubectl` calls pointed at a local cluster, because the session kubeconfig is exported only inside `session.sh`. Exporting `KUBECONFIG` to the session file in the shell fixed it.
- The Prometheus explorer is under Managed Prometheus in the workspace menu. The Graph tab was used for every reading. The Grid tab returned no results for a query whose Graph drew lines.
- `latency-sli` returned no chart over a range that included minutes with no traffic, and drew a line over 19:45 to 20:40.
- The Logs time range picker is in UTC. 19:42 to 20:42 local is 17:42 to 18:42 UTC.

## Not in this session

- The missing-data alert.
- The six other runbooks.
- Issue #98.
- A repeated destroy.
