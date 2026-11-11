# Release notes

v0.1.0 is the first release.

## v0.1.0

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
