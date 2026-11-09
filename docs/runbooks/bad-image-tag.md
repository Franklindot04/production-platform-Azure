# Bad image tag

## Trigger

A pull request changes `image.tag` in `gitops/dev/values/sample-service.yaml` to a tag that does not work, and it is merged. Session 2 experiment 4 does this on purpose and reverts it with Git.

## Impact

Argo CD syncs the new tag (automated sync with prune and self-heal). The Deployment starts new pods with the bad image. The chart sets no update strategy, so the Kubernetes defaults apply. With 2 replicas the defaults start one extra pod and allow no pod to be unavailable, so the old pods keep serving while the new pod fails. This follows from the defaults and is not observed. The hypothesis of experiment 4 is that Argo CD rolls back and the service recovers after the revert.

If the tag is empty, the chart fails to render (`image.tag must be set`) and the Application `sample-service` shows an error instead of a rollout.

## First checks

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows the old pods and a new pod in `ErrImagePull`, `ImagePullBackOff` or another failed state.
2. `kubectl describe pod -n apps <new pod name>` (planned, not run). The events show the pull error or the probe failures.
3. `kubectl get deploy sample-service -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'` (planned, not run). It shows the image the Deployment asks for.
4. `kubectl get application sample-service -n argocd` (planned, not run). It shows the sync and health state.
5. `git log --oneline -- gitops/dev/values/sample-service.yaml` (planned, not run). It shows the commits that changed the tag, newest first. The commit before the bad one holds the last tag that worked.
6. `kubectl rollout status deploy/sample-service -n apps` (planned, not run). It shows whether the rollout completes.

## Likely causes

- The tag does not exist in `ghcr.io/franklindot04/sample-service`. Tags are full commit SHAs (ADR 0013). See [image-pull-refused.md](image-pull-refused.md).
- The image exists but the service fails its probes or exits. The log shows it. See [pod-not-ready.md](pod-not-ready.md).
- The tag is empty or the values file is not valid, so the chart does not render.
- The pull request was made by the tag workflow after an image was published (ADR 0018).

## Fix

1. Revert the pull request that changed the tag. Use the revert button on the merged pull request on GitHub, or make a revert commit on a branch and open a pull request. Merge it. `main` accepts changes through pull requests only.
2. Argo CD syncs the revert by itself. The refresh interval is not set in this repository, so how long it takes is not known.
3. To see the sync without waiting, read the Application: `kubectl get application sample-service -n argocd -w` (planned, not run). It shows the state change.
4. Do not fix it with `kubectl set image` or `kubectl edit`. Self-heal reverts it to the tag in Git. See [argocd-drift.md](argocd-drift.md).

Unsure: how long Argo CD takes to notice the merge. It is not set in `gitops/` or `gitops/bootstrap/argocd-values.yaml`.

## Verify

1. `kubectl get deploy sample-service -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'` (planned, not run). It shows the earlier tag.
2. `kubectl rollout status deploy/sample-service -n apps` (planned, not run). The rollout completes.
3. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods are ready.
4. `kubectl get application sample-service -n argocd` (planned, not run). The Application is `Synced` and `Healthy`.

## Rollback

Revert the revert pull request to deploy the bad tag again. Do this only to repeat the experiment.

## Source

Session 2 experiment 4, ADR 0018, ADR 0013, `docs/workflows.md`.

## Status

not exercised
