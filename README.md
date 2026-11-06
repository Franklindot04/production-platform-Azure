# Production Platform / Azure

A personal project to build and operate a platform on Microsoft Azure: infrastructure as code, a Kubernetes cluster, delivery pipelines, monitoring, incident handling and cost control.

The goal is to practice the full SRE and DevOps loop on one system: build it, deploy it, measure it, break it and fix it.

## Status

Early stage. Nothing is deployed yet.

What exists today:

- Repository files: `.gitignore`, `.editorconfig`, issue and PR templates, `CONTRIBUTING.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- A decision record process in `docs/adr/`.
- `infrastructure/`: two Terraform roots for `dev` and the bootstrap script for the state backend. The roots define resource groups, a virtual network, a subnet and an AKS cluster. They were applied once. The session layer was destroyed afterwards, and only the empty persistent resource group exists. `session.sh` creates, destroys and checks the session layer. Plans and the first create are in `docs/plans/` and ADR 0012.
- The state backend in Azure: one resource group, one storage account and the `tfstate-dev` container, created with `infrastructure/bootstrap/bootstrap.sh`.
- A GitHub Actions workflow that checks Terraform format and validity on pull requests.
- `applications/sample-service/`: a Go service with health endpoints and a settable latency and error rate, and its Dockerfile. `helm/sample-service/`: its chart. `kubernetes/`: namespaces, quotas and network policies. `gitops/`: the Argo CD Applications and `dev` values. `tests/kind/`: a script that checks all of it in a local `kind` cluster. None of it has run on AKS.
- Planned work, written up as GitHub issues.

What does not exist yet: a running cluster, build and deploy pipelines, dashboards, runbooks. The README will change as each of these is built.

## Planned tools

These are the tools planned for the project. None is in use yet.

- Cloud: Microsoft Azure
- Infrastructure as code: Terraform
- Kubernetes: Azure Kubernetes Service (AKS)
- CI/CD: GitHub Actions
- GitOps: Argo CD
- Packaging: Docker and Helm
- Observability: Azure Monitor, Prometheus, OpenTelemetry
- Identity and secrets: Microsoft Entra ID, Azure Key Vault, Azure RBAC

Tool choices may change. Changes will be recorded as ADRs.

The planned design is described in [docs/architecture.md](docs/architecture.md). The plan for the remaining epics and the live sessions is in [docs/plan.md](docs/plan.md).

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
- `docs/`: architecture documents, ADRs, runbooks and postmortems. Exists.

## How work is tracked

Work is tracked in GitHub issues.

- Eight epics group the work by area: architecture and foundation, Azure infrastructure, Kubernetes platform, CI/CD and GitOps, observability and SRE, security and governance, incident management and recovery, reliability and optimization.
- Each epic has sub-issues. Each sub-issue has acceptance criteria as a checkbox list.
- A sub-issue is closed by the pull request that completes it.

A Jira project (key PP) is planned for the roadmap. Issues may reference PP-numbers once it exists.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for branch names, commit style, the pull request flow and what "done" means here.

## Community and security

- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md): how to behave in this project and how to report problems.
- [SECURITY.md](SECURITY.md): how to report a vulnerability. Do not use public issues for this.

## License

MIT. See [LICENSE](LICENSE).
