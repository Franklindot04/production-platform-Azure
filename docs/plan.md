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
5. There are two live sessions of about 2 hours each. A third session of 30 to 45 minutes is allowed if Session 1 fails a gate.
6. Each pull request is based on `main`, so a pull request that depends on another waits for it to merge.

## 2. Decisions taken

| Area | Decision | Record |
|---|---|---|
| Registry | `ghcr.io`, public package | ADR 0013 (planned) |
| Sample service | Go, health endpoints, settable latency and error rate | ADR 0014 (planned) |
| Network policy | Azure's own engine, set in the session Terraform | ADR 0015 (planned) |
| Ingress | The lighter of the AKS add-on or one controller, chosen from the documentation. HTTP on the plain IP, no domain, no certificate | ADR 0016 (planned) |
| Bootstrap | A `bootstrap` step in `session.sh` installs Argo CD with Helm and a root Application. No third Terraform root | ADR 0017 (planned) |
| Argo CD | Part of Epic 3. Epic 4 covers CI. The admin credential is generated, read at run time and never stored. The UI is reached by port-forward only | ADR 0017 (planned) |
| First image | Published by a GitHub Actions workflow | ADR 0018 (planned) |
| Image tag update | A workflow opens a pull request that changes the tag | ADR 0018 (planned) |
| Traces and dashboards | No paid managed Grafana. Dashboards are queries in the Azure Monitor workspace. The trace backend is chosen in the ADR | ADR 0019 (planned) |
| Logs | No cluster-wide log collection. Logs are read with `kubectl logs` | ADR 0019 (planned) |
| Policy and scanning | Tools chosen in the ADR | ADR 0020 (planned) |
| Cluster sign-in | Entra ID and Azure RBAC, local accounts kept as a fallback | ADR 0021 (planned) |
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
| 0013 | Use GitHub Container Registry for images |
| 0014 | Write the sample service in Go |
| 0015 | Use Azure network policy |
| 0016 | Choose the ingress |
| 0017 | Bootstrap Argo CD from the session script |
| 0018 | Update the image tag with a pull request |
| 0019 | Choose the trace backend and Grafana hosting |
| 0020 | Choose policy and scanning tools |
| 0021 | Sign in to the cluster with Entra ID |

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

PR 3 and PR 6 can be open at the same time. PR 4 and PR 5 can be open at the same time once PR 3 has merged. Corrections to rows of the architecture document that these changes touch are made in the same commits.

## 6. Day plan

Days are relative to the start.

| Day | Work |
|---|---|
| 1 | PR 1 and PR 2 merged. PR 3 started. |
| 2 | PR 3 and PR 4. The persistent Terraform for PR 6 is written and planned. |
| 3 | PR 5, PR 6 and PR 7. The persistent layer is applied after the plan is approved. A dry run of the bootstrap on `kind`. |
| 4 | PR 8, then Session 1 ([run sheet](sessions/session-1.md)). PR 9. |
| 5 | Fixes from Session 1. PR 10. |
| 6 | Session 2 ([run sheet](sessions/session-2.md)). |
| 7 | PR 11 and PR 12. Tags and releases. |

## 7. What is cut first

If Session 1 fails a gate or time runs out, the work is cut in this order:

1. Entra ID access to the cluster (#56).
2. OIDC identity for pull request plans (#47).
3. Dashboards as code (#51), reduced to the queries that Session 2 needs.
4. The experiments in Session 2 that are marked optional.

Cluster-wide log collection and a managed Grafana are already out of scope.

## 8. Steps only the maintainer can do

1. Make the `ghcr.io` package public in the GitHub settings after the first image is published.
2. Allow Actions to create pull requests in the repository settings.
3. Enable GitHub Pages for `docs/` in the repository settings.
4. Set the Azure budget with alerts. None exists yet.
5. Approve each plan before it is applied, and say when a release may be created.

## 9. Releases

A release is created only after the maintainer says so in chat.

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
