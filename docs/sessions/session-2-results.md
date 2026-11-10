# Live session 2: results

Results of the run described in [session-2.md](session-2.md). Issue #50.

## Scope

The session created the `dev` session layer from zero, bootstrapped it, measured the sample service under load, ran failure experiments and destroyed the layer. The first postmortem comes from the fault injection: [1-error-injection-availability-alerts.md](../postmortems/1-error-injection-availability-alerts.md). The list of what was not tested is at the end of this page.

## Step durations

| Step | Duration |
|---|---|
| Apply of the session layer | 532 s |
| Bootstrap | 203 s |
| Bootstrap to all four Applications Synced and Healthy, with `/healthz` answering 200 | 37 s |
| Total from start to healthy | 772 s |
| Destroy (10 resources destroyed) | 416 s |
| Leftovers check | 3 s |

The four Applications are `root`, `cluster-rules`, `opentelemetry-collector` and `sample-service`.

## Capacity

Measured after the node drain and the uncordon.

| Request | One node | The other node |
|---|---|---|
| CPU | 62% | 99% |
| Memory | 39% | 48% |

Pods that moved during the drain do not return to the other node.

## Check results

| Check | Result | Issue |
|---|---|---|
| 1. Rebuild | The new cluster reached Healthy with no manual step after bootstrap | |
| 2. Range | From the allowed address the ingress answered 200 and `kubectl get nodes` exited 0. From another public address (a VPN exit) the ingress timed out and `kubectl get nodes` exited 1. Only one other address was tried | |
| 3. Baseline load | `SCENARIO=baseline`, 10 minutes, 20 requests per second: 12,001 requests, 0 failed. Latency: average 118 ms, median 98 ms, p90 150 ms, p95 201 ms, slowest 1.83 s. Both thresholds passed (p95 under 500 ms, failures under 1%) | |
| 4. Ramp load | `SCENARIO=ramp`, 17.5 minutes, up to 160 requests per second: 62,818 requests, 0 failed. Latency: average 145 ms, median 105 ms, p90 216 ms, p95 427 ms, slowest 3.96 s. 31 iterations were dropped near the top of the ramp. Both thresholds passed. p95 doubled compared with the baseline, and 160 requests per second is not a breaking point | |
| 5. Pod delete | With 2 replicas, one pod was deleted. 1 of 90 probes failed, and the Deployment was back to 2/2 ready after about 3 seconds | |
| 6. Node drain | `kubectl drain` with `--ignore-daemonsets --delete-emptydir-data --timeout=300s` on the node holding a sample service pod. The flags were accepted. The drain ran until the timeout and exited 1, because the disruption budget of metrics-server blocked its eviction and its second replica could not be scheduled. All 236 probes returned 200, because the other replica stayed on the other node. Seven pods stayed Pending with insufficient CPU on the remaining node: one sample service replica, three Argo CD pods, the second metrics-server pod, retina-agent and the collector. After the uncordon, six of the seven were running within about 4 minutes. The retina-agent pod stayed Pending | #98 |
| 7. Fault injection | `error_rate` 1 was set on both pods through `PUT /admin/config` on the admin port (the response echoes the new config), with 10 requests per second for 10 minutes. All 6,001 requests failed, and k6 exited 99 as the thresholds were crossed. The AvailabilityFastBurn alert (severity 1) sent its email about 4 min 40 s after the fault was set. The AvailabilitySlowBurn alert (severity 2) fired about 13 min 45 s after. After the error rate was set back to 0, the fast alert resolved about 15 minutes later and the slow alert about 25 minutes later, which follows the long window | |
| 8. Log queries | `monitoring/logs/failed-requests.kql` returned 6,001 rows, all `GET /work` with status 500, which equals the failed requests in the load run. `monitoring/logs/slow-requests.kql` returned 0 rows, because no latency was injected | |
| 9. Bad image tag and rollback | The tag in `gitops/dev/values/sample-service.yaml` was changed to a tag that does not exist, through a pull request. Argo CD showed the change about 165 s after the merge. The new pod went `ErrImagePull`, then `ImagePullBackOff` with a not found error. The two old pods kept running, `/healthz` returned 200 on every probe, and the Deployment stayed at 2/2 ready with 1 up to date. A revert pull request restored the tag. The Deployment was back to 2/2 ready and up to date 4 min 30 s after the revert was merged, and the Application went from Degraded to Healthy | |
| 10. Teardown | The destroy completed with exit 0 on the first run, so the repeat step added to the destroy did not run. The leftovers check exited 0 with no compute, public IP addresses, load balancers, managed disks or unexpected resource groups | #89 |

## Manual steps and fixes

None were needed for the rebuild.

## Not tested

- `slow-requests.kql` with real slow requests
- The latency alerts (LatencyFastBurn, LatencySlowBurn) and the latency-burn runbook
- Removal of a node instance
- The network policy block experiment
- The repeat step of the destroy after a failed destroy
- The range test from more than one other address
- A screenshot of the Argo CD UI
- A cost snapshot

## Open issues

- #98: a node drain does not complete on the two node cluster.
