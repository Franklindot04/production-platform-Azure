# ADR 0006: Choose the GitOps tool

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

The project plans to deploy cluster workloads from Git. A GitOps controller inside the cluster pulls the desired state from the repository and applies it. The cluster is destroyed after each session, so the controller is installed again each time, and the repository is the only source of truth.

## Decision

- Use Argo CD.
- Terraform installs Argo CD with Helm when the cluster is created. Argo CD then reads an Application that points at the `gitops/` folder of this repository and syncs the rest.
- The repository is public, so Argo CD needs no repository credentials for now. If the repository becomes private, a read-only deploy key is added.

## Consequences

- Each new cluster rebuilds its workloads from Git. This tests the GitOps flow every session.
- Argo CD is self-managed, not an AKS-managed extension. Upgrades and the admin credential are our job.
- Argo CD has a web UI and an API. Access must be limited, and the exposure choice is made in the Epic 4 (#4) issues.
- Argo CD uses cluster resources. Node size must allow for it.

## Alternatives considered

- Flux, through the AKS extension. Managed by Azure and lighter. Not chosen, because the maintainer picked Argo CD and wants its UI.
- Applying manifests from a pipeline. Simpler, but it is not GitOps and gives no drift detection.
