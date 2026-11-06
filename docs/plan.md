# Delivery plan for Epics 3 to 8

Status: planned. None of the work below is done, except where an issue is marked closed.

The plan covers the Kubernetes platform, delivery, observability, security, incident handling and reliability work. It is built around two limits: the cluster exists only during a live session, and the target subscription has a regional vCPU quota of 4 in `swedencentral` (ADR 0003).

## 1. Constraints

1. The cluster is created at the start of a session and destroyed at the end (ADR 0009). Everything in it must come from code, with no manual step.
2. About 2.5 vCPU and 9.8 GiB of requests are left for workloads after the system pods (ADR 0012). The tools below are not measured yet:
   - Argo CD
   - the metrics agent
   - the OpenTelemetry Collector
   - the ingress
   - the network policy daemon
   - the sample service
3. A create takes about 7 minutes and a destroy about 7 minutes (ADR 0012). Each live session pays that first.
4. Anything that does not need Azure is checked first with `kind`, `helm lint`, `helm template` and `kubeconform`. `kind` does not show the AKS load balancer, Azure CNI Overlay behaviour or whether network policy is enforced there.
5. Each pull request is based on `main`, so a pull request that depends on another waits for it to merge.

## 2. Decisions taken

| Area | Decision | Record |
|---|---|---|
| Registry | `ghcr.io`, public package | [ADR 0013](adr/0013-container-registry.md) |
| Sample service | Go, health endpoints, settable latency and error rate | [ADR 0014](adr/0014-sample-service.md) |
| Network policy | Azure's own engine, set in the session Terraform | [ADR 0015](adr/0015-network-policy-engine.md) |
| Ingress | The lighter of the AKS add-on or one controller, chosen from the documentation. HTTP on the plain IP, no domain, no certificate | [ADR 0016](adr/0016-ingress.md) |
| Bootstrap | A `bootstrap` step in `session.sh` installs Argo CD with Helm and a root Application. No third Terraform root | [ADR 0017](adr/0017-argocd-bootstrap.md) |
| Argo CD | Part of Epic 3. Epic 4 covers CI. The admin credential is generated, read at run time and never stored. The UI is reached by port-forward only | [ADR 0017](adr/0017-argocd-bootstrap.md) |
| First image | Published by a GitHub Actions workflow | [ADR 0018](adr/0018-image-tag-update.md) |
| Image tag update | A workflow opens a pull request that changes the tag | [ADR 0018](adr/0018-image-tag-update.md) |
| Traces and dashboards | No paid managed Grafana. Dashboards are queries in the Azure Monitor workspace. The trace backend is chosen in the ADR | [ADR 0019](adr/0019-trace-backend-and-grafana.md) |
| Logs | No cluster-wide log collection. Logs are read with `kubectl logs` | [ADR 0019](adr/0019-trace-backend-and-grafana.md) |
| Policy and scanning | Tools chosen in the ADR | [ADR 0020](adr/0020-policy-and-scanning-tools.md) |
| Cluster sign-in | Entra ID and Azure RBAC, local accounts kept as a fallback | [ADR 0021](adr/0021-entra-id-cluster-access.md) |
| Load generator | k6 from the maintainer's machine | Issue #60 |
| Alert email | A run-time input, never committed | Issue #48 |

## 3. Sub-issues

Epic 3, Kubernetes Platform (#3). Issues #33 to #35 are closed.

| Issue | Title |
|---|---|
| #39 | Decision records for the Kubernetes platform |
| #40 | Sample service in Go |
| #41 | Chart, cluster rules and GitOps layout |
| #42 | Network policy engine and ingress in the session Terraform |
| #43 | Argo CD bootstrap in session.sh |
| #44 | Live session 1: converge and measure |

Epic 4, CI/CD and GitOps (#4):

| Issue | Title |
|---|---|
| #45 | CI for the service, chart and manifests |
| #46 | Image publish and tag update |
| #47 | OIDC identity for pull request plans |

Epic 5, Observability and SRE (#5):

| Issue | Title |
|---|---|
| #48 | Persistent monitoring layer |
| #49 | Metrics |
| #50 | Traces |
| #51 | Dashboards as code |
| #52 | SLIs, SLOs and alerts |

Epic 6, Security and Governance (#6):

| Issue | Title |
|---|---|
| #53 | Key Vault and workload identity |
| #54 | Least-privilege roles and secret rules |
| #55 | Policy and scanning checks |
| #56 | Entra ID access to the cluster |

Epic 7, Incident Management and Recovery (#7):

| Issue | Title |
|---|---|
| #57 | Runbooks |
| #58 | Incident process and postmortem template |
| #59 | Measured recovery |

Epic 8, Reliability and Optimization (#8):

| Issue | Title |
|---|---|
| #60 | Load tests |
| #61 | Failure experiments and live session 2 |
| #62 | Cost review |
| #63 | Documentation site and releases |

## 4. Architecture decision records

Numbering continues from ADR 0012.

| ADR | Title |
|---|---|
| [0013](adr/0013-container-registry.md) | Use GitHub Container Registry for images |
| [0014](adr/0014-sample-service.md) | Write the sample service in Go |
| [0015](adr/0015-network-policy-engine.md) | Use Azure network policy |
| [0016](adr/0016-ingress.md) | Choose the ingress |
| [0017](adr/0017-argocd-bootstrap.md) | Bootstrap Argo CD from the session script |
| [0018](adr/0018-image-tag-update.md) | Update the image tag with a pull request |
| [0019](adr/0019-trace-backend-and-grafana.md) | Choose the trace backend and Grafana hosting |
| [0020](adr/0020-policy-and-scanning-tools.md) | Choose policy and scanning tools |
| [0021](adr/0021-entra-id-cluster-access.md) | Sign in to the cluster with Entra ID |

## 5. Pull requests, in order

| PR | Content | Issues | Needs |
|---|---|---|---|
| 1 | This plan and the run sheets | none | none |
| 2 | ADR 0013 to 0021 and the architecture document corrections | #39 | 1 |
| 3 | Sample service, chart, cluster rules, GitOps layout, `kind` checks | #40, #41 | 2 |
| 4 | CI, image publish, tag update workflow | #45, #46 | 3 |
| 5 | Session Terraform (policy engine, ingress) and the `bootstrap` step | #42, #43 | 3 |
| 6 | Persistent layer and identities: workspaces, Key Vault, OIDC | #47, #48, #53 | 2 |
| 7 | Observability code: scrape configuration, OpenTelemetry, dashboards, SLOs, alerts | #49, #50, #51, #52 | 3, 6 |
| 8 | Security: scans, role table, secret rules, Entra ID access | #54, #55, #56 | 4, 6 |
| 9 | Session 1 record, screenshots, fixes | #44 | 3 to 8 |
| 10 | Runbooks and incident process | #57, #58 | 9 |
| 11 | Load tests, experiments, Session 2 record, recovery time, cost review | #59, #60, #61, #62 | 9, 10 |
| 12 | Documentation site, changelog, release notes | #63 | 11 |

## 6. What is cut first

If Session 1 fails a gate or time runs out, the work is cut in this order:

1. Entra ID access to the cluster (#56).
2. OIDC identity for pull request plans (#47).
3. Dashboards as code (#51), reduced to the queries that Session 2 needs.
4. The experiments in Session 2 that are marked optional.

Cluster-wide log collection and a managed Grafana are already out of scope.

## 7. Releases

A release is created when the maintainer approves it.

| Tag | After |
|---|---|
| v0.1.0 | Foundation and Azure infrastructure (Epics 1 and 2, done) |
| v0.2.0 | PR 3 to 5, checked on `kind` |
| v0.3.0 | Session 1: the GitOps flow and the first observability data |
| v0.4.0 | Security and identity (PR 8) |
| v0.5.0 | SLOs and alerts proven |
| v0.6.0 | Runbooks and incident process (PR 10) |
| v0.7.0 | Load tests and failure experiments (Session 2) |
| v0.9.0 | Cost review and the documentation site |
| v1.0.0 | All epics closed and the documents consistent |
