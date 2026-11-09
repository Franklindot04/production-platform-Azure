# Workflows

The GitHub Actions workflows of the repository. Every action is pinned to a full commit SHA with its version in a comment. No workflow uses a stored client secret. The plan workflow uses secrets that hold identifiers only. Each one sets the permissions it needs and nothing more.

| Workflow | File | Runs on | Permissions |
|---|---|---|---|
| Terraform checks | `terraform-checks.yml` | Pull requests that change `infrastructure/` | `contents: read` |
| Terraform plan | `terraform-plan.yml` | Pull requests that change `infrastructure/` | None at the top, and `contents: read` and `id-token: write` in the one job |
| Service, chart and manifest checks | `app-checks.yml` | Pull requests that change `applications/`, `helm/`, `kubernetes/`, `gitops/` or `tests/kind/` | `contents: read` |
| Security scans | `security-scans.yml` | Pull requests that change `infrastructure/`, `kubernetes/`, `helm/`, `gitops/`, `applications/` or `.trivyignore.yaml` | `contents: read` |
| Publish image | `image-publish.yml` | Pushes to `main` that change `applications/sample-service/`, and manual runs | `contents: read`, and `packages: write` in the one job that pushes |
| Open pull request for the image tag | `image-tag-bump.yml` | When Publish image succeeds on `main` | None at the top, and `contents: write` and `pull-requests: write` in the one job |

## Terraform plan

Runs `terraform plan -lock=false` for the two `dev` roots (ADR 0022). The workflow is written and has not run. The identity it needs is planned and is not applied.

- One job. It does nothing for pull requests from forks.
- If the secret `AZURE_CLIENT_ID` is not set, the first step prints a notice and every other step is skipped.
- It logs in with `azure/login` and an OIDC token. No client secret is used.
- The persistent plan uses `-refresh=false`. It sets `TF_VAR_alert_email` to a placeholder address, so the plan shows a change to the action group receiver. The session plan sets `TF_VAR_api_authorized_ip_ranges` to a documentation range.
- The plan identity has no access to the session resource group. The session plan works while the session layer is destroyed. If the layer exists, the refresh fails.
- The plan output is not saved.
- `azure/login` is not pinned yet. The `uses` line holds a placeholder that actionlint reports until the full commit SHA is added.

## Service, chart and manifest checks

Two jobs, both running `tests/kind/check.sh`:

- `static` runs `go vet`, `go test`, `gofmt`, `helm lint`, `kubeconform` and `yamllint` if it is installed. Helm is installed with a pinned version. `kubeconform` is installed with `go install` at a pinned version.
- `kind` runs after `static` and runs the whole script, which creates a `kind` cluster, installs the chart and the cluster rules, and checks them. `kind` is installed with `go install` at a pinned version.

The checks are described in `tests/kind/README.md`.

## Security scans

Two jobs run Trivy (ADR 0020).

- `config` scans the repository for misconfiguration in the Terraform, the Kubernetes manifests and the chart, and then scans the files for secrets. The chart is rendered with the dev values, because it needs `image.tag`.
- `image` builds `applications/sample-service` and scans the image for vulnerabilities and secrets.
- A finding of severity HIGH or CRITICAL fails the run.
- An accepted finding goes into `.trivyignore.yaml` with a reason.
- The action is pinned by full SHA and Trivy is pinned to v0.69.3, because the version tags of the action and Trivy v0.69.4 were replaced with malicious code in March 2026.
- Nothing is uploaded and the workflow has no permissions beyond `contents: read`.
- The action inputs, the environment variables and the ignore-file format are checked by the first run.

## Publish image

Builds `applications/sample-service` for `linux/amd64`, which the AKS nodes use, and pushes it to `ghcr.io/<owner>/sample-service` with the full commit SHA as the only tag (ADR 0013). It logs in with the built-in token. The image carries the labels set by the metadata action.

## Open pull request for the image tag

After Publish image succeeds on `main`, this workflow checks out `main` and sets the tag in `gitops/dev/values/sample-service.yaml` to the commit SHA with `.github/scripts/set-image-tag.sh`. `.github/scripts/open-image-tag-pr.sh` then commits it to a branch named `chore/sample-service-image-<short SHA>` and opens a pull request (ADR 0018). It never pushes to `main`.

The branch is named after the SHA, so it can exist already:

- If the branch is not on the remote, it is pushed.
- If the branch holds the same change, which means the same tree on the same parent, it is not pushed.
- If the branch holds something else, it is replaced with a force push that is checked against the commit that was read from the remote.

The pull request is opened in each case. If one is already open for the branch, that one is used. Open pull requests from earlier branches of that name are closed.

A pull request created with the built-in token does not start other workflows, so the checks do not run on it.

## Repository settings the workflows need

These are settings in GitHub. A workflow cannot change them.

1. The plan workflow needs the secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TFSTATE_ACCOUNT_NAME`. They are set after the persistent root is applied. Without `AZURE_CLIENT_ID` the workflow prints a notice and skips its steps.
2. Actions must be allowed to create pull requests: Settings, Actions, General, "Allow GitHub Actions to create and approve pull requests". Without it, the last step of the tag workflow fails.
3. The package must be public after its first publish: the package settings on GitHub. Until then the cluster cannot pull the image without a credential. A public package cannot be made private again.

## Check the workflows locally

```bash
actionlint
./tests/kind/check.sh --static
.github/scripts/set-image-tag.sh gitops/dev/values/sample-service.yaml <40 character SHA>
```

The last command changes the file. Reset it with `git checkout gitops/dev/values/sample-service.yaml`.
