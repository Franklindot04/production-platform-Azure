# Live session 1: converge and measure

Status: run. The results are in [session-1-results.md](session-1-results.md). Issue #32. Items marked planned have not been built or run.

Goal: create the cluster, let the code bring it to a working state without manual steps, measure what the tools use, and destroy everything.

Time box: about 2 hours. Teardown starts at 1:45 whatever is unfinished. A gate that fails stops the session. If the gate cannot be fixed within 15 minutes, the session ends with a teardown. One short third session of 30 to 45 minutes is allowed to finish the failed part.

Rules:

- Every apply is preceded by a plan that the maintainer has seen and approved.
- Output that is saved or shown is masked: no subscription or tenant IDs, no addresses.
- The authorized range is set at run time and is not written down.
- The Argo CD credential is read once, at run time, and is not stored.

## Before the session

1. The pull requests for the sample service, the cluster rules, the bootstrap step, the persistent layer and the observability code are merged.
2. The image is published on `ghcr.io` and the package is public.
3. The persistent layer is applied.
4. A budget with alerts is set in Azure.
5. The bootstrap step has been run against `kind` and passed.
6. The secret `sample-service-secret` is set in the Key Vault (one time, `infrastructure/README.md`). Without it the sample service pods do not start.
7. The Entra ID group for cluster admins exists, the maintainer is a member, and `kubelogin` is installed (`infrastructure/README.md`, planned).
8. The resource providers listed in `infrastructure/README.md` are registered.

## Run sheet

| Time | Step | Command or action | Record |
|---|---|---|---|
| 0:00 | Preflight | `az account show`, vCPU use is 0 of 4, `./infrastructure/session.sh check` exits 0, the authorized range is set in `TF_VAR_api_authorized_ip_ranges`, the admin group is set in `TF_VAR_cluster_admin_group_object_id` | Pass or fail of each item |
| 0:05 | Plan | `./infrastructure/session.sh up` | The masked plan, shown for approval |
| 0:08 | Create | `./infrastructure/session.sh up --apply` after approval | Time taken |
| 0:15 | Bootstrap | `./infrastructure/session.sh bootstrap` | Time to Argo CD ready |
| 0:25 | **Gate A** | Nodes Ready. Applications Healthy and Synced. The sample service answers `/healthz` on the ingress address | Time from `up` to healthy |
| 0:35 | **Gate B**, capacity | `kubectl describe nodes`, `kubectl top pods -A`, requests and limits per tool | The capacity budget table |
| 0:50 | Network policy | A test pod in another namespace cannot reach the service. The allowed path works. DNS works | Result of each check |
| 1:00 | GitOps flow | Merge a prepared tag-bump pull request, watch the sync, then revert it and watch the rollback | Time to sync and to roll back |
| 1:15 | Observability | A metric in the Azure Monitor workspace, a trace in the backend, test queries from `monitoring/prometheus/request-rate.promql` and `monitoring/logs/failed-requests.kql`. `metrics.scrape.enabled` is set to `true` in `gitops/dev/values/sample-service.yaml` through a pull request after Gate A, and the target is then checked in the Azure Monitor workspace. The bootstrap creates the secret `appinsights-connection`, and the Collector pod is checked Running | Masked screenshots |
| 1:35 | Identity | The bootstrap part `identity` has turned on the Key Vault mount. The sample service reads one Key Vault secret with workload identity. `kubectl get nodes` works through the Entra ID sign-in with the non-admin kubeconfig, and the local credential still works for the bootstrap. The maintainer reads the Argo CD credential once with `./infrastructure/session.sh argocd-password` | Pass or fail of each check |
| 1:45 | Wrap up | Save output and screenshots in `docs/images`, masked | Files saved |
| 1:50 | Teardown | `./infrastructure/session.sh down` then `down --yes`, then `./infrastructure/session.sh check`. If the first `down --yes` stops on a public IP, run it again (#89) | Output of `check`. The session ends when `check` exits 0 |

## Gates

**Gate A.** Pass when the nodes are Ready, every Argo CD application is Healthy and Synced, and the service answers on the ingress address. On a fail, read the Argo CD application status and the pod events. After 15 minutes without a fix, tear down.

**Gate B.** Pass when the requests of all tools fit in the capacity that is left, with room for the sample service to run two replicas. On a fail, apply the cut list in the delivery plan, tear down, and fix the requests in the repository before the next session.

## What is recorded

1. Time for each step: create, bootstrap, healthy.
2. Allocatable capacity per node, and requests and limits per tool.
3. Which settings AKS accepted or refused.
4. The result of each check above.
5. Anything done by hand. Each manual step is a defect to fix before Session 2.

## After the session

1. `session.sh check` exits 0.
2. The results go into a pull request, with the fixes found.
3. The issue #32 criteria are ticked only for what was checked.
