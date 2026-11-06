# Workflows

The GitHub Actions workflows of the repository. Every action is pinned to a full commit SHA with its version in a comment. No workflow uses a stored secret. Each one sets the permissions it needs and nothing more.

| Workflow | File | Runs on | Permissions |
|---|---|---|---|
| Terraform checks | `terraform-checks.yml` | Pull requests that change `infrastructure/` | `contents: read` |
| Service, chart and manifest checks | `app-checks.yml` | Pull requests that change `applications/`, `helm/`, `kubernetes/`, `gitops/` or `tests/kind/` | `contents: read` |
| Publish image | `image-publish.yml` | Pushes to `main` that change `applications/sample-service/`, and manual runs | `contents: read`, and `packages: write` in the one job that pushes |
| Open pull request for the image tag | `image-tag-bump.yml` | When Publish image succeeds on `main` | None at the top, and `contents: write` and `pull-requests: write` in the one job |

## Service, chart and manifest checks

Two jobs, both running `tests/kind/check.sh`:

- `static` runs `go vet`, `go test`, `gofmt`, `helm lint`, `kubeconform` and `yamllint` if it is installed. Helm is installed with a pinned version. `kubeconform` is installed with `go install` at a pinned version.
- `kind` runs after `static` and runs the whole script, which creates a `kind` cluster, installs the chart and the cluster rules, and checks them. `kind` is installed with `go install` at a pinned version.

The checks are described in `tests/kind/README.md`.

## Publish image

Builds `applications/sample-service` for `linux/amd64`, which the AKS nodes use, and pushes it to `ghcr.io/<owner>/sample-service` with the full commit SHA as the only tag (ADR 0013). It logs in with the built-in token. The image carries the labels set by the metadata action.

## Open pull request for the image tag

After Publish image succeeds on `main`, this workflow checks out `main`, sets the tag in `gitops/dev/values/sample-service.yaml` to the commit SHA with `.github/scripts/set-image-tag.sh`, pushes a branch named `chore/sample-service-image-<short SHA>`, and opens a pull request (ADR 0018). It then closes any open pull request from an earlier branch of that name. It never pushes to `main`.

A pull request created with the built-in token does not start other workflows, so the checks do not run on it.

## Repository settings the workflows need

These are settings in GitHub. A workflow cannot change them.

1. Actions must be allowed to create pull requests: Settings, Actions, General, "Allow GitHub Actions to create and approve pull requests". Without it, the last step of the tag workflow fails.
2. The package must be public after its first publish: the package settings on GitHub. Until then the cluster cannot pull the image without a credential. A public package cannot be made private again.

## Check the workflows locally

```bash
actionlint
./tests/kind/check.sh --static
.github/scripts/set-image-tag.sh gitops/dev/values/sample-service.yaml <40 character SHA>
```

The last command changes the file. Reset it with `git checkout gitops/dev/values/sample-service.yaml`.
