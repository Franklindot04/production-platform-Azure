# Production Platform / Azure

A personal project to build and operate a platform on Microsoft Azure: infrastructure as code, a Kubernetes cluster, delivery pipelines, monitoring, incident handling and cost control.

The goal is to practice the full SRE and DevOps loop on one system: build it, deploy it, measure it, break it and fix it.

The documentation site is at https://franklindot04.github.io/production-platform-Azure/. Its pages are the files in `docs/`.

## Status

Early stage. Sessions 1 and 2 created, checked and destroyed the session layer. No cluster is running now. The results are in [docs/sessions/session-1-results.md](docs/sessions/session-1-results.md) and [docs/sessions/session-2-results.md](docs/sessions/session-2-results.md).

What exists today:

- Repository files: `.gitignore`, `.editorconfig`, issue and PR templates, `CONTRIBUTING.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- A decision record process in `docs/adr/`.
- `infrastructure/`: two Terraform roots for `dev` and the bootstrap script for the state backend. The persistent root is applied: the monitoring workspaces, the alerts, the Key Vault and the identities. The session root defines a virtual network, a subnet and an AKS cluster. It was applied once and the session layer was destroyed afterwards. `session.sh` creates, destroys and checks the session layer. Plans and the first create are in `docs/plans/` and ADR 0012.
- The state backend in Azure: one resource group, one storage account and the `tfstate-dev` container, created with `infrastructure/bootstrap/bootstrap.sh`.
- GitHub Actions workflows: Terraform checks, Terraform plan, Service, chart and manifest checks, Security scans, Publish image, and Open pull request for the image tag. See `docs/workflows.md`. All six have run on GitHub. The Terraform plan workflow plans the two `dev` roots on pull requests from this repository.
- `applications/sample-service/`: a Go service with health endpoints and a settable latency and error rate, and its Dockerfile. `helm/sample-service/`: its chart. `kubernetes/`: namespaces, quotas and network policies. `gitops/`: the Argo CD Applications and `dev` values. `tests/kind/`: a script that checks all of it in a local `kind` cluster. The sample service ran on AKS in Session 1. It was served through the managed ingress, its metrics reached the Azure Monitor workspace and its traces reached Application Insights.
- Planned work, written up as GitHub issues.

Ten runbooks are written in `docs/runbooks/`. Three were exercised in Session 2. What does not exist now: a running cluster and dashboards. The README will change as each of these is built.

## Tools

These are the tools of the project. Azure, AKS, Argo CD, Azure Monitor, Prometheus, OpenTelemetry, Microsoft Entra ID, Azure Key Vault and Azure RBAC ran in a live session.

- Cloud: Microsoft Azure
- Infrastructure as code: Terraform
- Kubernetes: Azure Kubernetes Service (AKS)
- CI/CD: GitHub Actions
- GitOps: Argo CD
- Packaging: Docker and Helm
- Observability: Azure Monitor, Prometheus, OpenTelemetry
- Identity and secrets: Microsoft Entra ID, Azure Key Vault, Azure RBAC

Tool choices may change. Changes will be recorded as ADRs.

The planned design is described in [docs/architecture.md](docs/architecture.md). The plan for the remaining epics and the live sessions is in [docs/plan.md](docs/plan.md). The roles and the secret rules are in [docs/security.md](docs/security.md).

## Planned repository layout

The folders below marked as existing are in the repository. The others are planned. Names may change when the work starts.

- `infrastructure/`: Terraform modules and environments. Exists.
- `applications/`: a sample service and its tests. Exists.
- `kubernetes/`: cluster manifests. Exists.
- `helm/`: Helm charts. Exists.
- `gitops/`: Argo CD application definitions. Exists.
- `tests/`: checks that need no Azure. Exists.
- `monitoring/`: dashboards, alert rules and SLO definitions.
- `security/`: policies and scanning configuration.
- `docs/`: architecture documents, ADRs and runbooks (`docs/runbooks/`, written, three exercised in Session 2). Postmortems have a template (`docs/postmortems/`), and one has been written: [1-error-injection-availability-alerts.md](docs/postmortems/1-error-injection-availability-alerts.md). Exists.

## How work is tracked

Work is tracked in GitHub issues.

- Eight epics group the work by area: architecture and foundation, Azure infrastructure, Kubernetes platform, CI/CD and GitOps, observability and SRE, security and governance, incident management and recovery, reliability and optimization.
- Each epic has sub-issues. Each sub-issue has acceptance criteria as a checkbox list.
- A sub-issue is closed by the pull request that completes it.

A Jira project (key PP) is planned for the roadmap. Issues may reference PP-numbers once it exists.

## Project history

How the repository was built and why its issue and pull request history is short: [docs/history.md](docs/history.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for branch names, commit style, the pull request flow and what "done" means here.

## Community and security

- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md): how to behave in this project and how to report problems.
- [SECURITY.md](SECURITY.md): how to report a vulnerability. Do not use public issues for this.

## License

MIT. See [LICENSE](LICENSE).
