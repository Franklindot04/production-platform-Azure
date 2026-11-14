# Delivery plan for Epics 3 to 8

Status: [Session 1](sessions/session-1-results.md), [Session 2](sessions/session-2-results.md) and [Session 3](sessions/session-3-results.md) have run. For the other work below, only an issue that is marked closed is done.

The plan covers the Kubernetes platform, delivery, observability, security, incident handling and reliability work. It is built around two limits: the cluster exists only during a live session, and the target subscription has a regional vCPU quota of 4 in `swedencentral` (ADR 0003).

## 1. Constraints

1. The cluster is created at the start of a session and destroyed at the end (ADR 0009). Everything in it must come from code, with no manual step.
2. About 2.5 vCPU and 9.8 GiB of requests are left for workloads after the system pods (ADR 0012). The tools below were measured in Session 1 and fit (`docs/sessions/session-1-results.md`):
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
| Load generator | k6 from the maintainer's machine | Issue #49 |
| Alert email | A run-time input, never committed | Issue #37 |

## 3. Sub-issues

Epic 3, Kubernetes Platform (#3). Issues #28 to #31 and #36 are closed.

| Issue | Title |
|---|---|
| #28 | Decision records for the Kubernetes platform |
| #29 | Sample service in Go |
| #30 | Chart, cluster rules and GitOps layout |
| #36 | Network policy engine and ingress in the session Terraform |
| #31 | Argo CD bootstrap in session.sh |
| #32 | Live session 1: converge and measure |

Epic 4, CI/CD and GitOps (#4):

| Issue | Title |
|---|---|
| #33 | CI for the service, chart and manifests |
| #34 | Image publish and tag update |
| #35 | OIDC identity for pull request plans |

Epic 5, Observability and SRE (#5):

| Issue | Title |
|---|---|
| #37 | Persistent monitoring layer |
| #38 | Metrics |
| #39 | Traces |
| #40 | Dashboards as code |
| #41 | SLIs, SLOs and alerts |

Epic 6, Security and Governance (#6):

| Issue | Title |
|---|---|
| #42 | Key Vault and workload identity |
| #43 | Least-privilege roles and secret rules |
| #44 | Policy and scanning checks |
| #45 | Entra ID access to the cluster |

Epic 7, Incident Management and Recovery (#7):

| Issue | Title |
|---|---|
| #46 | Runbooks |
| #47 | Incident process and postmortem template |
| #48 | Measured recovery |

Epic 8, Reliability and Optimization (#8):

| Issue | Title |
|---|---|
| #49 | Load tests |
| #50 | Failure experiments and live session 2 |
| #52 | Cost review |
| #51 | Documentation site and releases |

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
| 2 | ADR 0013 to 0021 and the architecture document corrections | #28 | 1 |
| 3 | Sample service, chart, cluster rules, GitOps layout, `kind` checks | #29, #30 | 2 |
| 4 | CI, image publish, tag update workflow | #33, #34 | 3 |
| 5 | Session Terraform (policy engine, ingress) and the `bootstrap` step | #36, #31 | 3 |
| 6 | Persistent layer and identities: workspaces, Key Vault, OIDC | #37, #42, #35 | 2 |
| 7 | Observability code: scrape configuration, OpenTelemetry, dashboards, SLOs, alerts | #38, #39, #40, #41 | 3, 6 |
| 8 | Security: scans, role table, secret rules, Entra ID access | #43, #44, #45 | 4, 6 |
| 9 | Session 1 record, screenshots, fixes | #32 | 3 to 8 |
| 10 | Runbooks and incident process | #46, #47 | 9 |
| 11 | Load tests, experiments, Session 2 record, recovery time, cost review | #48, #49, #50, #52 | 9, 10 |
| 12 | Documentation site, changelog, release notes | #51 | 11 |

## 6. What is cut first

If Session 1 fails a gate or time runs out, the work is cut in this order:

1. Entra ID access to the cluster (#45).
2. OIDC identity for pull request plans (#35).
3. Dashboards as code (#40), reduced to the queries that Session 2 needs.
4. The experiments in Session 2 that are marked optional.

Cluster-wide log collection and a managed Grafana are already out of scope.

## 7. Releases

A release is created when the maintainer approves it.

| Tag | After |
|---|---|
| v0.1.0 | The platform after Session 1 and Session 2, the first release ([release-notes.md](release-notes.md)) |
| v0.2.0 | The latency alerts LatencyFastBurn and LatencySlowBurn tested, the latency-burn runbook exercised, and `slow-requests.kql` run with real slow requests: done in [Session 3](sessions/session-3-results.md) (#41). The KQL files as saved searches (#40), applied. The cost snapshot (#52, [cost.md](cost.md)). See [release-notes.md](release-notes.md#v020) |
| v0.3.0 | The six runbooks not yet exercised: pod-not-ready, argocd-drift, network-policy-blocks-service, key-vault-mount-fails, image-pull-refused and session-leftovers (#46). A node drain that completes on the two node cluster (#98). The destroy repeat tested against a failed destroy (#89). Removal of a node instance. The network policy block experiment. The alert for missing data (planned) |
| v0.4.0 | Dashboards as code (#40): the workbook is done on main and not yet in a tagged release |
| v0.5.0 | Cost review: the budget with alerts defined in Terraform (planned). The cost snapshot is in v0.2.0 ([cost.md](cost.md)) |
| v0.6.0 | The environments `staging` and `prod` (planned) |
| v0.7.0 | Remaining checks: the range test from a second address, a screenshot of the Argo CD UI, and the image tag bump pull request tested |
| v1.0.0 | All epics closed and the documents consistent |
