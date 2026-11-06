# Project history

This page explains how the repository was built and why its issue and pull request history is short.

## How the project was built

Work was done in stages, each as a pull request with one commit per change and a linked issue.

1. **Foundation.** Repository files, issue forms, pull request template, contribution rules, license, code of conduct and security policy. Branch protection on `main`.
2. **Design.** The architecture document and the first decision records (ADR 0003 to 0012): region, naming, state backend, networking, environments, the first AKS plan.
3. **Azure infrastructure.** A Terraform folder layout, format and validate checks on pull requests, a state backend created with the Azure CLI, the session network design, and a first cluster that was created, recorded and destroyed.
4. **Kubernetes platform.** ADR 0013 to 0021, a sample service in Go, a Helm chart, namespaces, quotas and network policies, a GitOps layout, image publish to `ghcr.io`, a workflow that opens a pull request for the image tag, the network policy and ingress settings, and an Argo CD bootstrap step.

## Why the repository was recreated

On 2026-11-06 a pull request branch was found to contain commits with metadata that did not follow the project's rules. Commits that have been pushed cannot be edited in place. A force push replaced the branch, but the old commits stayed reachable by their hashes, and a pull request timeline links to them. The only way to remove them completely was to create a new repository.

## What was kept and what was not

- **Kept:** every file and the full commit history of `main`, up to the last merged pull request.
- **Not kept:** issues, pull requests, review discussion and the open branch. The open branch added the persistent monitoring layer, a Key Vault and the identity for pull request plans. That work is planned again.
- **Issue numbers changed.** A number such as `(#43)` in an older commit message refers to the earlier repository, not to the issue with that number here.

## Why most epics were recreated

The old issues were lost with the repository. Epics 1 and 2 and most of Epics 3 and 4 were recreated and closed, so the issue list matches the work that is already on `main`. Epics 5 to 8 and the live cluster session are open, because that work has not been done.