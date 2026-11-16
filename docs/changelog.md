# Changelog

This page lists what is on `main`. Release notes are in [release-notes.md](release-notes.md). Status text carries no dates. Each release entry carries its release date under its heading, in the form YYYY-MM-DD. Anything not built is marked planned.

## v0.3.0

Released 2026-11-16

The release notes are in [release-notes.md](release-notes.md#v030).

### Infrastructure

- The session layer holds the rule group `pp-dev-session-alerts` with the rule MissingRequestData, defined in `infrastructure/environments/dev/session/alerts.tf` and applied by `session.sh up --apply` (ADR 0033).
- The persistent layer holds the Azure Monitor workbook for the sample service, defined in `infrastructure/environments/dev/persistent/workbook.tf` and applied (ADR 0032).
- The destroy repeat was tested against a failed destroy in Session 4. A destroy can need more than one run of `session.sh down --yes`.

### Observability

- MissingRequestData did not fire at the start of Session 4. It fired after the sample service pods were deleted, sent mail and resolved ([sessions/session-4-results.md](sessions/session-4-results.md)).
- `availability-sli.promql` and `error-ratio.promql` return 1 and 0 when no 5xx series exists.

### Incident management

- The runbooks argocd-drift, missing-request-data, network-policy-blocks-service and session-leftovers were exercised in Session 4, and node-drain was exercised again. Eight of the eleven runbooks are exercised. See [runbooks/README.md](runbooks/README.md).
- The node drain completed with exit 0 in Session 4. Four pods stayed Pending for lack of CPU until the uncordon.
- A node instance was removed with `az aks nodepool delete-machines` and the pool was scaled back.

### Documentation

- The Session 4 plan and results, ADR 0032 and ADR 0033, and the runbook for MissingRequestData.
- The home page has a Session 4 results button, and the Session 4 plan and results are in the list of live sessions.
- The documentation site pins the Mermaid version, and tables keep their natural cell width on narrow screens.

## v0.2.0

Released 2026-11-14

The release notes are in [release-notes.md](release-notes.md#v020).

### Infrastructure

- The three KQL files in `monitoring/logs` are saved searches on the Log Analytics workspace `pp-dev-law`. They are defined in `infrastructure/environments/dev/persistent/saved-searches.tf` and applied (ADR 0031).

### Observability

- LatencyFastBurn and LatencySlowBurn fired and resolved in Session 3 with 800 ms injected on both pods ([sessions/session-3-results.md](sessions/session-3-results.md)).
- `slow-requests.kql` was run against real slow requests in Session 3.
- The alert for missing data is planned for v0.3.0.

### Incident management

- The latency-burn runbook was exercised in Session 3. Four of the ten runbooks are exercised. See [runbooks/README.md](runbooks/README.md).

### Documentation

- The Session 3 plan and results, the cost page ([cost.md](cost.md)), and ADR 0031 with the amendment of ADR 0027.
- The documentation site footer shows the license and the latest release tag, which the browser reads from the releases of the repository. The home page has a Session 3 results button, the last button of the row is centred on mobile, and the cost page is in the sidebar.
- Notes on the session kubeconfig and the latency SLI range in the infrastructure and monitoring READMEs.

## v0.1.0

Released 2026-11-11

The first release. The release notes are in [release-notes.md](release-notes.md#v010).

### Infrastructure

- A state backend in Azure: one resource group, one storage account and the `tfstate-dev` container, created with `infrastructure/bootstrap/bootstrap.sh`.
- Two Terraform roots for `dev`, one per layer, each with its own state file.
- The persistent root is applied. It defines the resource group, the Azure Monitor and Log Analytics workspaces, Application Insights, the action group, the four burn-rate alerts, the Key Vault, the identity for pull request plans and the identity of the sample service with its Key Vault roles.
- The session root defines a virtual network, a node subnet and an AKS cluster with Azure network policy, the managed ingress, managed Prometheus, workload identity and Entra ID sign-in with Azure RBAC. It was applied in Session 1 and Session 2 and destroyed after each.
- `infrastructure/session.sh` creates, destroys and checks the session layer, and runs the bootstrap step.
- `session.sh down --yes` repeats the destroy once after a wait. The repeat has not been run against a failed destroy.
- The budget with alerts for `dev` is set in Azure and is not defined in Terraform. Defining it in Terraform is planned.
- The environments `staging` and `prod` are planned.

### Kubernetes platform

- A sample service in Go with health endpoints, a settable latency and error rate, and its Dockerfile.
- A Helm chart for the sample service.
- Namespaces, quotas and network policies.
- A script that checks the chart and the cluster rules in a local `kind` cluster.
- The sample service ran on AKS and was served through the managed ingress.
- The sample service mounts a Key Vault secret through workload identity.

### GitOps and CI/CD

- The Argo CD bootstrap step of `session.sh`, and the Applications `root`, `cluster-rules`, `sample-service` and `opentelemetry-collector`.
- Six GitHub Actions workflows: Terraform checks, Terraform plan, Service, chart and manifest checks, Security scans, Publish image, and Open pull request for the image tag. See [workflows.md](workflows.md).
- The image is published to `ghcr.io`, and a pull request sets its tag in `gitops/dev/values/sample-service.yaml`.
- A bad image tag was deployed and reverted through a pull request in Session 2.

### Observability

- A metrics endpoint on the admin port of the sample service, scraped by managed Prometheus through a PodMonitor.
- Traces from the sample service through the OpenTelemetry Collector to Application Insights.
- Query files under `monitoring/`: six PromQL files and three KQL files.
- SLOs and four burn-rate alerts. See [slos.md](slos.md). The availability alerts fired and sent mail in Session 2. The latency alerts have not been tested.
- Dashboards are planned. Saved searches and an alert for missing data are planned.

### Security

- Roles and secret rules: [security.md](security.md).
- Trivy scans in CI.
- Pull request plans sign in to Azure through OIDC, with a federated credential that includes the owner and repository IDs.
- Sign-in to the cluster with Entra ID and Azure RBAC.

### Incident management

- Ten runbooks. Three were exercised in Session 2: availability-burn, bad-image-tag and node-drain. See [runbooks/README.md](runbooks/README.md).
- An incident process with a severity table: [incident-process.md](incident-process.md).
- A postmortem template and one postmortem: [postmortems/README.md](postmortems/README.md).

### Load and failure tests

- A k6 script with the scenarios `smoke`, `baseline` and `ramp`.
- The baseline and ramp scenarios were run against the cluster in Session 2.
- Experiments run in Session 2: a pod delete, a node drain, error injection and a bad image tag. The drain does not complete on the two node cluster (#98).

### Documentation

- Decision records ADR 0001 to ADR 0030.
- The architecture document, the plan, the project history and the workflows page.
- Run sheets and results for Session 1 and Session 2.
- Files for a documentation site built from the `docs/` folder (#51).
- A custom theme for the documentation site, kept in `docs/`: grouped navigation, search, and light and dark mode (#51).
