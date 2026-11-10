# Argo CD drift

## Trigger

A resource that Argo CD manages is edited by hand with `kubectl`, and the cluster no longer matches Git. Session 2 experiment 5 does this on purpose. The hypothesis is that Argo CD reverts the edit.

## Impact

All Applications under `gitops/dev/apps/` use automated sync with prune and self-heal: `cluster-rules`, `sample-service` and `opentelemetry-collector`, and the `root` Application that creates them. Self-heal restores the state in Git when a resource changes. A hand edit is therefore expected to be undone. Session 1 showed that self-heal reverted a manual change to the Ingress.

## First checks

1. `kubectl get applications -n argocd` (planned, not run). It shows the sync and health state of each Application. `OutOfSync` that does not clear points to a revert that did not happen.
2. `kubectl describe application sample-service -n argocd` (planned, not run). The status and the events show the last sync, its result and any error.
3. `kubectl get application sample-service -n argocd -o jsonpath='{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'` (planned, not run). It shows the two states only.
4. `kubectl get pods -n argocd` (planned, not run). It shows whether the Argo CD components are running.
5. `kubectl get application sample-service -n argocd -o jsonpath='{.spec.syncPolicy}{"\n"}'` (planned, not run). It shows whether automated sync is still set.
6. The Argo CD UI shows the diff per resource. Reach it with `kubectl -n argocd port-forward svc/argocd-server 8080:443` and read the credential with `./infrastructure/session.sh argocd-password` (planned, not run). The credential is printed to the terminal only.

## Likely causes

The edit was not reverted because:

- The field is one that Argo CD is told to ignore. The root Application ignores `/spec/source/helm/parameters` of the Applications it creates and respects that setting, so the parameters set by `session.sh bootstrap identity` stay (`gitops/dev/root-application.yaml`, ADR 0029). An edit to those parameters is not reverted.
- Automated sync was turned off on the Application, so it stays `OutOfSync`.
- The Application cannot sync. For example the chart does not render, or the repository cannot be read. The Application status shows the error.
- The Argo CD components are not running.
- The resource is not in Git. Argo CD does not remove a resource it does not manage. A resource that someone created by hand in `apps` stays.
- Argo CD has not noticed yet. A change on `main` was synced in up to about 3 minutes in Session 1.

## Fix

1. For an edit that should go away, wait and watch: `kubectl get application sample-service -n argocd -w` (planned, not run). It shows the Application go `OutOfSync` and back to `Synced`.
2. If the Application is `OutOfSync` and does not sync, read the error in `kubectl describe application sample-service -n argocd` (planned, not run) and fix the cause named there.
3. To ask for a refresh: `kubectl annotate application sample-service -n argocd argocd.argoproj.io/refresh=hard --overwrite` (planned, not run). It tells Argo CD to compare again.
4. To sync from the UI, press Sync on the Application.
5. For a change that should stay, make it in Git through a pull request. A hand edit does not last.

Unsure: the refresh annotation in step 3. It is the documented Argo CD way to ask for a refresh. It is not used anywhere in this repository.

## Verify

1. `kubectl get applications -n argocd` (planned, not run). Every Application is `Synced` and `Healthy`.
2. Read the resource that was edited, for example `kubectl get deploy sample-service -n apps -o jsonpath='{.spec.replicas}{"\n"}'` (planned, not run). It shows the value from Git (2).

## Rollback

If the edit was meant to stay for a test, repeat it by hand and expect it to be reverted again. Nothing else to undo.

## Source

Session 2 experiment 5, ADR 0017, `gitops/README.md`, `gitops/dev/root-application.yaml`.

## Status

not exercised
