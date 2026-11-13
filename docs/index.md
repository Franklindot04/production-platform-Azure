---
layout: home
start:
  - title: Architecture
    url: /architecture.html
    stage: build
  - title: Runbooks
    url: /runbooks/
    stage: fix
  - title: Session 1 results
    url: /sessions/session-1-results.html
    stage: break
  - title: Session 2 results
    url: /sessions/session-2-results.html
    stage: break
lead: "A personal project to build and operate a platform on Microsoft Azure: infrastructure as code, a Kubernetes cluster, delivery pipelines, monitoring, incident handling and cost control."
---
# Production Platform / Azure

The goal is to practice the full SRE and DevOps loop on one system: build it, deploy it, measure it, break it and fix it.

## The loop

1. [Build](architecture.md)
   The components, the layers and the decisions behind them.
2. [Deploy](workflows.md)
   The workflows that check, scan and publish the code.
3. [Measure](slos.md)
   The SLIs, the targets and the burn-rate alerts.
4. [Break](sessions/session-2-results.md)
   The load runs and the failure experiments of Session 2.
5. [Fix](runbooks/README.md)
   One runbook for each known failure.
{: .loop}

Then the loop starts again with build.

The repository is at [github.com/Franklindot04/production-platform-Azure](https://github.com/Franklindot04/production-platform-Azure). These pages are the files of its `docs/` folder.

## Design and plan

- [Architecture](architecture.md): components, layers, environments, identity, cost and open questions.
- [Cost](cost.md): the cost after Session 1 and Session 2, compared with the budget.
- [Plan](plan.md): the plan for the remaining epics and the live sessions.
- [Project history](history.md): how the repository was built and why its history is short.
- [Saved plans](plans/README.md): the saved Terraform plans of the `dev` roots.

## Delivery and security

- [Workflows](workflows.md): the GitHub Actions workflows.
- [Security](security.md): roles and secret rules.

## Reliability

- [SLOs](slos.md): the SLIs, the targets and the burn-rate alerts.
- [Incident process](incident-process.md): severity levels and what to do at each step.
- [Runbooks](runbooks/README.md): one procedure per known failure, with the status of each.
- [Postmortems](postmortems/README.md): the rules, the template and the written postmortems.

## Live sessions

- [Session 1](sessions/session-1.md): the plan.
- [Session 1 results](sessions/session-1-results.md): the measured results of the first live session.
- [Session 2](sessions/session-2.md): the plan.
- [Session 2 results](sessions/session-2-results.md): the measured results of the second live session.
- [Session 3](sessions/session-3.md): the plan for the latency alerts test.
- [Session 3 results](sessions/session-3-results.md): the measured results of the third live session.

## Changes

- [Changelog](changelog.md): what is on `main`.
- [Release notes](release-notes.md): the notes of v0.1.0, the first release.
- [Documentation site](site.md): how the site is built and previewed.

## Decision records

- [ADR 0001: Template](adr/0001-template.md)
- [ADR 0002: Record decisions as ADRs](adr/0002-record-decisions-as-adrs.md)
- [ADR 0003: Choose Azure region and resource naming convention](adr/0003-region-and-naming-convention.md)
- [ADR 0004: Use Azure Storage as the Terraform state backend](adr/0004-terraform-state-backend.md)
- [ADR 0005: Choose the AKS networking model](adr/0005-aks-networking-model.md)
- [ADR 0006: Choose the GitOps tool](adr/0006-gitops-tool.md)
- [ADR 0007: Authenticate GitHub Actions to Azure with OIDC](adr/0007-github-actions-oidc-to-azure.md)
- [ADR 0008: Choose the metrics and dashboard stack](adr/0008-observability-stack.md)
- [ADR 0009: Set cost guardrails and teardown policy](adr/0009-cost-guardrails.md)
- [ADR 0010: Separate environments by resource group](adr/0010-environment-separation.md)
- [ADR 0011: Design the session network](adr/0011-session-network-design.md)
- [ADR 0012: Plan the first AKS cluster](adr/0012-first-aks-plan.md)
- [ADR 0013: Use GitHub Container Registry for images](adr/0013-container-registry.md)
- [ADR 0014: Write the sample service in Go](adr/0014-sample-service.md)
- [ADR 0015: Use Azure network policy](adr/0015-network-policy-engine.md)
- [ADR 0016: Choose the ingress](adr/0016-ingress.md)
- [ADR 0017: Bootstrap Argo CD from the session script](adr/0017-argocd-bootstrap.md)
- [ADR 0018: Update the image tag with a pull request](adr/0018-image-tag-update.md)
- [ADR 0019: Choose the trace backend and Grafana hosting](adr/0019-trace-backend-and-grafana.md)
- [ADR 0020: Choose policy and scanning tools](adr/0020-policy-and-scanning-tools.md)
- [ADR 0021: Sign in to the cluster with Entra ID](adr/0021-entra-id-cluster-access.md)
- [ADR 0022: Define the persistent layer and the pull request plan identity](adr/0022-persistent-layer-and-plan-identity.md)
- [ADR 0023: Serve metrics on the admin port](adr/0023-metrics-on-the-admin-port.md)
- [ADR 0024: Enable managed Prometheus on the cluster](adr/0024-managed-prometheus.md)
- [ADR 0025: Send traces with the Azure Monitor exporter and a connection string](adr/0025-collector-connection-string.md)
- [ADR 0026: Trace the sample service with the OpenTelemetry SDK](adr/0026-service-tracing.md)
- [ADR 0027: Keep dashboard queries as files under monitoring/](adr/0027-dashboard-queries-as-files.md)
- [ADR 0028: Set SLOs for the sample service and alert on burn rate](adr/0028-slos-and-burn-rate-alerts.md)
- [ADR 0029: Give the sample service access to Key Vault with workload identity](adr/0029-workload-identity-and-vault-access.md)
- [ADR 0030: Set the incident process and write postmortems](adr/0030-incident-process-and-postmortems.md)
- [ADR 0031: Deploy the KQL queries as saved searches](adr/0031-kql-saved-searches.md)
