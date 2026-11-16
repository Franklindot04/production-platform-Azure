# Release notes

v0.1.0 is the first release. v0.2.0 and v0.3.0 follow it.

## v0.3.0

Released 2026-11-16

v0.3.0 adds the alert for missing data, the workbook, and the results of a fourth live session to v0.2.0. It is the same `dev` environment. The environment was created, checked and destroyed in a fourth live session. The cluster exists only while a live session runs.

### What is in this release

Tested in Session 4 ([results](sessions/session-4-results.md)):

- The alert MissingRequestData (rule group `pp-dev-session-alerts` in the session layer, ADR 0033). It did not fire at the start of the session. It fired after the sample service pods were deleted and the data stopped, the mail was sent, and it resolved after the data returned with a resolved mail.
- The node drain completes with exit 0. Four pods stayed Pending for lack of CPU on the remaining node until the uncordon (#98).
- The destroy repeat test (#89) used a `CanNotDelete` lock on the session resource group. The destroy took three runs of `session.sh down --yes`. The first two exited 1, and the third destroyed the rest and exited 0, and `check` then exited 0.
- Removal of a node instance: `az aks nodepool delete-machines` with the node name as the value of `--machine-names` removed the node. AKS did not recreate it within 3 minutes. `az aks nodepool scale` restored it.
- Eight of the eleven runbooks are exercised, as the status lines in the [runbook index](runbooks/README.md) show: availability-burn, bad-image-tag, latency-burn, node-drain, argocd-drift, missing-request-data, network-policy-blocks-service and session-leftovers. Session 4 exercised argocd-drift, missing-request-data, network-policy-blocks-service, node-drain and session-leftovers.

Platform changes since v0.2.0:

- The session layer holds the rule group `pp-dev-session-alerts` with the rule MissingRequestData, severity 2. It is created by `session.sh up --apply` and destroyed with the session layer (ADR 0033). The runbook is [runbooks/missing-request-data.md](runbooks/missing-request-data.md).
- The persistent layer holds one Azure Monitor workbook for the sample service, defined in `infrastructure/environments/dev/persistent/workbook.tf` (ADR 0032).
- The queries `availability-sli.promql` and `error-ratio.promql` return 1 and 0 when no 5xx series exists.
- The documentation site pins the Mermaid version, and tables keep their natural cell width on narrow screens.
- The admin config examples in the load test README and in the availability-burn runbook send the `Content-Type` header.

Documentation: the Session 4 plan and results, ADR 0032 and ADR 0033, the runbook for MissingRequestData, and the status lines of the exercised runbooks.

Decision records: ADR 0001 to ADR 0033, listed on the [home page](index.md).

### What is not in this release

- The budget with alerts for `dev` is set in Azure. Defining it in Terraform is planned.
- The environments `staging` and `prod` are planned.

### Known limitations

- The runbooks pod-not-ready, key-vault-mount-fails and image-pull-refused were run in Session 4 and are not marked as exercised. Their corrections are tracked in #151.
- The cause of the block on the node resource group `pp-dev-aks-nodes-rg` during a destroy was not found.
- Not recorded on the results page: the time taken by `session.sh bootstrap` and the state of the Applications after it, the steps run and the results of experiments 2 to 4, the steps run in experiment 5, the time of the data stop in the missing data test, the requests per node before the drain, and the time until the restored node was `Ready`.
- Deleting `allow-metrics-scrape` alone did not stop a running scrape.
- The pod state during the single node phase of the node removal was not measured.
- The limits of v0.2.0 that Session 4 did not change stay: the expression value at fire for LatencySlowBurn is not recorded, the observed firing order of the latency alerts differs from the calculated order with no cause established, and the request count in the log table (34145) differs from the k6 count (36001).
- The cost page covers Session 1 and Session 2. The costs of Session 3 and Session 4 are not in it.
- The range test from a second address and a screenshot of the Argo CD UI have not been done. The regional quota is 4 vCPU, and the node pool has two nodes ([architecture.md](architecture.md)).

### Rebuild steps

The steps are the same as for v0.1.0 (see [v0.1.0](#v010)), and `session.sh up --apply` now also creates the rule group `pp-dev-session-alerts`. The run sheet of the latest session is in [session-4.md](sessions/session-4.md). In Session 4 `session.sh up --apply` added 11 resources. A destroy can need more than one run of `session.sh down --yes`: repeat it and `session.sh check` until `check` exits 0 ([runbooks/session-leftovers.md](runbooks/session-leftovers.md)).

### Where to read more

The full list of changes is in the [changelog](changelog.md). The sessions are documented in [Session 1](sessions/session-1.md), [Session 2](sessions/session-2.md), [Session 3](sessions/session-3.md) and [Session 4](sessions/session-4.md), with their results in [Session 1 results](sessions/session-1-results.md), [Session 2 results](sessions/session-2-results.md), [Session 3 results](sessions/session-3-results.md) and [Session 4 results](sessions/session-4-results.md).

## v0.2.0

Released 2026-11-14

v0.2.0 adds the latency alerts test, the KQL saved searches and the cost page to v0.1.0. It is the same `dev` environment. The environment was created, checked and destroyed in a third live session. The cluster exists only while a live session runs.

### What is in this release

Tested in Session 3 ([results](sessions/session-3-results.md)):

- The latency alerts LatencyFastBurn and LatencySlowBurn. Both fired and resolved with 800 ms injected on both pods. LatencyFastBurn fired 13 min 39 s after the injection and resolved 11 min 39 s after the set back. LatencySlowBurn fired 17 min 37 s after the injection and resolved 20 min 38 s after the set back.
- The latency-burn runbook ([runbooks/latency-burn.md](runbooks/latency-burn.md)) was exercised. Four of the ten runbooks are exercised: availability-burn, bad-image-tag, node-drain and latency-burn.
- `monitoring/logs/slow-requests.kql` was run against real slow requests. A summary query counted 12001 slow requests over the run range, with durations from 800.033 ms to 802.873 ms.

Platform changes since v0.1.0:

- The three KQL files in `monitoring/logs` are saved searches on the Log Analytics workspace `pp-dev-law`. They are defined in `infrastructure/environments/dev/persistent/saved-searches.tf` and applied (ADR 0031).
- The cost page [cost.md](cost.md) holds the cost after Session 1 and Session 2 and compares it with the budget.
- The documentation site footer shows the license and the latest release tag, which the browser reads from the releases of the repository.
- The home page of the documentation site has a Session 3 results button, the last button of the row is centred on mobile, and the cost page is listed in the sidebar.

Documentation: the Session 3 plan and results, ADR 0031 with the amendment of ADR 0027, the notes in the infrastructure and monitoring READMEs on the session kubeconfig and the latency SLI range, and the dating of the v0.1.0 entries.

Decision records: ADR 0001 to ADR 0031, listed on the [home page](index.md).

### What is not in this release

- Dashboards are planned. Only the query files exist.
- An alert for missing data is not built. It is planned for v0.3.0.
- The budget with alerts for `dev` is set in Azure. Defining it in Terraform is planned.
- The environments `staging` and `prod` are planned.

### Known limitations

- The expression value at fire for LatencySlowBurn is not recorded.
- The observed firing order differs from the calculated order. The plan calculated LatencySlowBurn at 11.4 min and LatencyFastBurn at 12.8 min after the injection. The observed times are 17 min 37 s and 13 min 39 s. No cause is established.
- The request count in the log table (34145) differs from the k6 count (36001). The two counts are not equated.
- The cost page covers Session 1 and Session 2. The cost of Session 3 is not in it.
- The limits of v0.1.0 that Session 3 did not change stay: #98 (a node drain does not complete on the two node cluster), #89 (the destroy repeat has not been run against a failed destroy), #46 (six of the ten runbooks have not been exercised: pod-not-ready, argocd-drift, network-policy-blocks-service, key-vault-mount-fails, image-pull-refused and session-leftovers), #40 (dashboards are not built), removal of a node instance, the network policy block experiment, the range test from a second address, a screenshot of the Argo CD UI, and the image tag bump pull request. The regional quota is 4 vCPU, and the node pool has two nodes ([architecture.md](architecture.md)).

### Rebuild steps

The steps are the same as for v0.1.0 (see [v0.1.0](#v010)). The run sheet of the latest session is in [session-3.md](sessions/session-3.md). In Session 3 `session.sh up --apply` took 13 min 1 s and `session.sh bootstrap` took 2 min 27 s.

### Where to read more

The full list of changes is in the [changelog](changelog.md). The sessions are documented in [Session 1](sessions/session-1.md), [Session 2](sessions/session-2.md) and [Session 3](sessions/session-3.md), with their results in [Session 1 results](sessions/session-1-results.md), [Session 2 results](sessions/session-2-results.md) and [Session 3 results](sessions/session-3-results.md).

## v0.1.0

Released 2026-11-11

v0.1.0 is the `dev` environment as built. It was created, checked and destroyed in two live sessions. The cluster exists only while a live session runs.

### What is in this release

Built components, as listed in the [architecture](architecture.md):

- Terraform, which creates all Azure resources.
- State storage, which holds the Terraform state and is shared by all environments.
- The virtual network for the nodes (session layer).
- The AKS cluster (session layer).
- Key Vault (persistent layer).
- Azure Monitor and Log Analytics: the workspaces, Application Insights, the action group and the four burn-rate alerts (persistent layer).
- The pull request plan identity, which lets a pull request run `terraform plan` (persistent layer).
- GitHub Actions, with Trivy scans as the policy checks.

Delivery workflows, all of which have run on GitHub (see [workflows.md](workflows.md)):

- Terraform checks
- Terraform plan
- Service, chart and manifest checks
- Security scans
- Publish image
- Open pull request for the image tag

Run in the live sessions:

- The sample service in Go, its Dockerfile and its Helm chart.
- Namespaces, quotas and network policies.
- The Argo CD bootstrap step of `infrastructure/session.sh` and the four Applications `root`, `cluster-rules`, `opentelemetry-collector` and `sample-service`.
- Metrics scraped by managed Prometheus, and traces sent to Application Insights.
- The SLOs and the four burn-rate alerts ([slos.md](slos.md)).
- A k6 script with the scenarios `smoke`, `baseline` and `ramp`.

Runbooks and incident handling:

- Ten runbooks ([runbooks/README.md](runbooks/README.md)). Three were exercised in Session 2: availability-burn, bad-image-tag and node-drain.
- An incident process with a severity table ([incident-process.md](incident-process.md)).
- A postmortem template and one postmortem ([postmortems/README.md](postmortems/README.md)).

Decision records: ADR 0001 to ADR 0030, listed on the [home page](index.md).

Results of the live sessions:

- [Session 1 results](sessions/session-1-results.md): Gate A and Gate B passed, and the four Applications were Synced and Healthy.
- [Session 2 results](sessions/session-2-results.md): the new cluster reached Healthy in 772 seconds with no manual step after bootstrap, and the baseline and ramp load runs had 0 failed requests.

### What is not in this release

- Dashboards are planned. Only the query files exist.
- Saved searches for the KQL files are planned.
- An alert for missing data is planned.
- The budget with alerts for `dev` is set in Azure. Defining it in Terraform is planned.
- The environments `staging` and `prod` are planned.

### Known limitations

- #98: a node drain does not complete on the two node cluster. Seven pods stay Pending, because the remaining node has insufficient CPU.
- #89: `session.sh down --yes` repeats the destroy once after a wait. The repeat has not been run against a failed destroy.
- #88: `monitoring/logs/slow-requests.kql` has not been run with real slow requests.
- #41: the latency alerts LatencyFastBurn and LatencySlowBurn have not been tested. The availability alerts fired and sent mail.
- #46: seven of the ten runbooks have not been exercised: latency-burn, pod-not-ready, argocd-drift, network-policy-blocks-service, key-vault-mount-fails, image-pull-refused and session-leftovers.
- #40: dashboards are not built. Dashboards as code are reduced to the query files that Session 2 needs.
- #52: no cost snapshot was taken in Session 2.
- Removal of a node instance has not been tested.
- The network policy block experiment has not been run.
- The range test used one other address. No second address was tried.
- A screenshot of the Argo CD UI has not been taken.
- The image tag bump pull request has not been tested.
- The regional quota is 4 vCPU, and the node pool has two nodes ([architecture.md](architecture.md)).

### Rebuild steps

The run sheet is in [session-2.md](sessions/session-2.md). The commands and the settings they need are in `infrastructure/README.md` in the repository.

1. Check that nothing remains: `./infrastructure/session.sh check` exits 0.
2. Set the authorized range in `TF_VAR_api_authorized_ip_ranges` and the admin group in `TF_VAR_cluster_admin_group_object_id`. Both are set at run time and are not stored.
3. Plan: `./infrastructure/session.sh up`. Read the plan.
4. Apply: `./infrastructure/session.sh up --apply`.
5. Bootstrap: `./infrastructure/session.sh bootstrap`.
6. Wait until the four Applications are Synced and Healthy and `/healthz` answers 200 on the ingress.
7. Tear down: `./infrastructure/session.sh down`, then `./infrastructure/session.sh down --yes`, then `./infrastructure/session.sh check`. The session ends when `check` exits 0.

### Where to read more

The full list of changes is in the [changelog](changelog.md). The sessions are documented in [Session 1](sessions/session-1.md), [Session 1 results](sessions/session-1-results.md), [Session 2](sessions/session-2.md) and [Session 2 results](sessions/session-2-results.md).
