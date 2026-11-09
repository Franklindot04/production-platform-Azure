# ADR 0018: Update the image tag with a pull request

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

After a build, the image tag in `gitops/` has to change so that Argo CD deploys the new image. The architecture document left the way open. `main` is protected, and nothing is pushed to it directly. Rollback is a Git revert.

## Decision

- Images are tagged with the commit SHA (ADR 0013).
- After the image is published, a workflow opens a pull request that changes the image tag in the `dev` values under `gitops/`. A person reviews and merges it. Argo CD then syncs.
- The workflow uses the built-in token with the permissions it needs and no stored credential. The repository setting that lets Actions create pull requests is turned on by the maintainer.
- A rollback is a revert of that pull request.

## Consequences

- A change to the cluster always has a pull request and a commit in `main`.
- A pull request created with the built-in token does not start other workflows. The bump pull request will not run the checks automatically. The change is one value, and the image was built from `main`.
- Each deploy needs the maintainer to merge a pull request.
- Promotion to other environments is not defined yet.

## Alternatives considered

- Argo CD Image Updater. One more controller in the cluster, which costs memory that is not measured.
- A direct commit to `main` by the workflow. The branch is protected, and the project does not push to `main`.
- A personal access token or an app, so that checks run on the bump pull request. It needs a stored credential, which the project avoids.
- The `latest` tag. A revert in Git would not roll back the deployment, and Argo CD could not see a change.
