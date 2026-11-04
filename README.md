# Production Platform / Azure

A personal project to build and operate a platform on Microsoft Azure: infrastructure as code, a Kubernetes cluster, delivery pipelines, monitoring, incident handling and cost control.

The goal is to practice the full SRE and DevOps loop on one system: build it, deploy it, measure it, break it and fix it.

## Status

Early stage. Nothing is deployed yet.

What exists today:

- Repository files: `.gitignore`, `.editorconfig`, issue and PR templates, `CONTRIBUTING.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- A decision record process in `docs/adr/`.
- Planned work, written up as GitHub issues.

What does not exist yet: Terraform code, a cluster, pipelines, dashboards, runbooks. The README will change as each of these is built.

## Planned tools

These are the tools planned for the project. None is in use yet.

- Cloud: Microsoft Azure
- Infrastructure as code: Terraform
- Kubernetes: Azure Kubernetes Service (AKS)
- CI/CD: GitHub Actions
- GitOps: Argo CD
- Packaging: Docker and Helm
- Observability: Azure Monitor, Prometheus, Grafana, OpenTelemetry
- Identity and secrets: Microsoft Entra ID, Azure Key Vault, Azure RBAC

Tool choices may change. Changes will be recorded as ADRs.

## Planned repository layout

Only `docs/` exists today. The other folders are planned. Names may change when the work starts.

- `infrastructure/`: Terraform modules and environments.
- `applications/`: a sample service and its tests.
- `kubernetes/`: cluster manifests.
- `helm/`: Helm charts.
- `gitops/`: Argo CD application definitions.
- `monitoring/`: dashboards, alert rules and SLO definitions.
- `security/`: policies and scanning configuration.
- `docs/`: architecture documents, ADRs, runbooks and postmortems.

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
