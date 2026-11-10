# Live session 1: results

Results of the run described in [session-1.md](session-1.md). Issue #90.

## Scope

The session created the `dev` session layer, bootstrapped Argo CD, ran the checks of the run sheet and destroyed the layer. Gate A and Gate B passed. The list of what was not tested is at the end of this page.

## Step durations

| Step | Duration |
|---|---|
| Create (apply of the session layer) | about 8 minutes, of which the cluster is about 5.5 minutes |
| Bootstrap | about 2 minutes |
| Argo CD picks up a change on `main` | up to about 3 minutes (the refresh cycle) |
| Destroy | about 14 minutes in two runs (#89) |

The first destroy run stopped on a public IP that the load balancer still held (`PublicIPAddressCannotBeDeleted`). The second run finished, and the leftover check exited 0.

## Capacity budget

Two `Standard_D2s_v5` nodes. Allocatable per node: 1900m CPU, about 5.8 GiB memory and 250 pods.

| Node | CPU requested | Memory requested |
|---|---|---|
| 1 | 1781m (93%) | 2499Mi (43%) |
| 2 | 1400m (73%) | 2794Mi (48%) |

Totals: 3800m CPU allocatable, 3181m requested (84%), 619m free. Memory: about 5.3 GiB requested of about 11.3 GiB.

Requests by part:

| Part | CPU | Memory |
|---|---|---|
| AKS add-ons | 2356m | 4494Mi |
| Managed ingress controller | 500m | 127Mi |
| Argo CD | 225m | 480Mi |
| OpenTelemetry Collector | 50m | 128Mi |
| Sample service, 2 replicas | 25m each | 32Mi each |

The Argo CD requests are made of the controller (100m, 256Mi), the repo server (50m, 128Mi), the server (50m, 64Mi) and Redis (25m, 32Mi).

Live use at the time: CPU 8% and 7%, memory 37% and 41% of the two nodes.

Limits are overcommitted: CPU 328% and 1588%, memory 249% and 968% of the nodes. The cause is the limits of the metrics add-on pods, the disk CSI node pods and kube-state-metrics.

Gate B passed. CPU requests, not memory, set the limit. Node 1 has only 119m CPU free.

## Settings AKS accepted

- Kubernetes 1.36.5 in `swedencentral`
- Free tier
- Node pool of two `Standard_D2s_v5` nodes with 32 GB OS disks and no autoscaling
- Azure CNI Overlay with the Azure network policy engine
- Managed ingress (web app routing). It registers the class `webapprouting.kubernetes.azure.com`
- Key Vault secrets provider with rotation off
- OIDC issuer and workload identity
- Entra ID integration with Azure RBAC
- API server authorized ranges
- Managed Prometheus metrics
- Node OS upgrade channel `None`

AKS refused none of them.

## Check results

| Check | Result | Issue |
|---|---|---|
| 1. Gate A | Passed after one fix. Nodes Ready, four Argo CD Applications Synced and Healthy, `GET /healthz` returns 200 through the ingress. The sample service stayed Progressing until the ingress class was corrected | #84 |
| 2. Gate B | Passed. See the capacity budget | |
| 3. Network policy | A pod in another namespace cannot reach the service (the connection times out). The ingress controller path works. DNS resolves | |
| 4. GitOps | A change merged to `main` was synced by Argo CD within about 3 minutes. The root Application left the Helm parameters set at run time on the child Application alone. Argo CD self-heal reverted a manual change to the Ingress | |
| 5. Metrics | The managed Prometheus scraped both sample service replicas through the PodMonitor (job `apps/sample-service`, `up` = 1). The Azure Monitor workspace answered the request-rate query by route (`/work`, `/healthz`, `/readyz`) | |
| 6. Traces | Server spans of the sample service reached Application Insights and appear in the `AppRequests` table with the role name `sample-service`. The request name includes the method, for example `GET /work` | |
| 7. Logs | The failed-requests query returned no rows. Its filter is `Name == "/work"` and the table holds `GET /work` | #88 |
| 8. Identity | Both sample service pods mounted the Key Vault secret through workload identity (token mount off) with no mount warnings. `kubelogin` sign-in in Azure CLI mode with the non-admin kubeconfig listed the nodes through the admin group and Azure RBAC. The Argo CD admin credential is read at run time with `session.sh argocd-password`, which refuses to print unless the output is a terminal | |
| 9. Fit | The add-on pods, Argo CD, the Collector and the sample service all fit on the two nodes | |
| 10. Teardown | The leftover check exits 0 after the second destroy run | #89 |

## Manual steps and fixes

1. The ingress class in `gitops/dev/values/sample-service.yaml` named a class that does not exist. It was set by hand as a Helm parameter, then fixed in Git (#84).
2. The `kind` install of the chart failed once scraping was on in the `dev` values, because `kind` has no PodMonitor definition. The `kind` install now turns scraping off (#86).

## Not tested

- Rollback of a change by revert
- `kubectl drain` behaviour
- Alert rules firing
- Dashboards
- Failure experiments
- Ingress access from an address outside the allowed range
- The image tag bump pull request

## Open issues

- #88: the failed-requests and slow-requests queries filter on `GET /work`. They have not been run with failing or slow requests.
- #89: the first destroy run stops on a public IP that the load balancer still holds, and a second run is needed. `down --yes` now repeats once after a wait. The repeat has not been run against the failure yet.
