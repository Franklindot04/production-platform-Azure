# Changelog

This page lists what is on `main`. Release notes are in [release-notes.md](release-notes.md). There are no dates and no version numbers. Anything not built is marked planned.

## Unreleased

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
