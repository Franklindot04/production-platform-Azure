# Image pull refused

## Trigger

A pod of the sample service shows `ErrImagePull` or `ImagePullBackOff`. The image `ghcr.io/franklindot04/sample-service:<tag>` cannot be pulled.

## Impact

New pods do not start. Pods that already run are not affected. During a rollout, the old pods keep serving. At the start of a session, no pod starts and the service has no ready pod.

## First checks

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). It shows `ErrImagePull` or `ImagePullBackOff`.
2. `kubectl describe pod -n apps <pod name>` (planned, not run). The events show the reason from the registry, such as `unauthorized`, `denied` or `not found`.
3. `kubectl get deploy sample-service -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'` (planned, not run). It shows the exact image and tag the pod asked for.
4. `git log --oneline -- gitops/dev/values/sample-service.yaml` (planned, not run). It shows when the tag changed.
5. `docker manifest inspect ghcr.io/franklindot04/sample-service:<tag>` from the maintainer's machine, signed out of `ghcr.io` (planned, not run). It shows whether an anonymous pull can find the tag.

Unsure: step 5. It is a common way to test an anonymous pull. It is not used in this repository, and `docker` is not part of the documented tools for this check.

## Likely causes

- The package is private. A package that is published for the first time is private. The maintainer makes it public in the package settings on GitHub, once, after the first publish (ADR 0013, `docs/workflows.md`, `gitops/README.md`). The cluster has no pull secret, so it can pull a public package only.
- The tag does not exist. The workflow Publish image has not pushed it, or it failed, or the tag in `gitops/dev/values/sample-service.yaml` is wrong. Tags are full commit SHAs.
- The first image was pushed by hand. The package then is not linked to the repository, and the built-in token cannot push to it (ADR 0013).
- GitHub is not reachable. A session depends on it (ADR 0013).

Other causes are not known from the repository.

## Fix

1. Package private: open the package settings on GitHub and change the visibility to public. A public package cannot be made private again, so check that the image holds no secret first.
2. Tag missing: run the workflow Publish image for the commit (it supports manual runs, `docs/workflows.md`), or set the tag back to one that exists by reverting the pull request that changed it. See [bad-image-tag.md](bad-image-tag.md).
3. After the cause is fixed, delete the failing pod so a new one pulls the image: `kubectl delete pod -n apps <pod name>` (planned, not run). The kubelet also retries with a back-off.
4. Do not create a pull secret or push the image by hand. ADR 0013 chose a public package and a first publish by the workflow.

## Verify

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods are ready.
2. `kubectl describe pod -n apps <pod name>` (planned, not run). The events show the image pulled.

## Rollback

Making a package public cannot be undone. Setting a tag back is a revert pull request in Git.

## Source

ADR 0013, `gitops/README.md`, `docs/workflows.md`.

## Status

not exercised
