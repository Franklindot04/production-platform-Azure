# ADR 0013: Use GitHub Container Registry for images

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

The sample service runs as a container image, and the cluster pulls it at the start of every session. A registry in Azure would be a resource of the persistent layer, and the cluster would need a role to pull from it. The repository is public.

Facts read from the GitHub documentation:

- A container package that is published for the first time is private.
- A package is made public in the package settings. The pages read describe no workflow or API for it. A public package cannot be made private again.
- A public container package can be pulled without signing in.
- A package published from a workflow with the built-in token is linked to the repository of the workflow.
- The built-in token cannot push to a package that was pushed earlier without being linked to the repository.
- A layer is limited to 10 GB and an upload to 10 minutes.
- The pages read do not state the storage, bandwidth or price for public packages.

## Decision

- Images are stored in `ghcr.io/<owner>/` as public packages. The cluster pulls them without a pull secret and without a role.
- The first publish is done by the workflow from issue #34, so that the package is linked to the repository. No image is pushed by hand first.
- The maintainer makes the package public in the GitHub settings once, after the first publish.
- Images are tagged with the commit SHA. How the tag reaches the cluster is in ADR 0018.
- The persistent layer has no registry.

## Consequences

- There is no registry to create, pay for or give roles to in Azure.
- Everything in a public package is public. An image must hold no secret, and a package cannot be made private again.
- Each session pulls the image from outside Azure. The data cost is not estimated.
- Starting a session depends on GitHub being available.
- Making the package public is a manual step in the GitHub settings, once.

## Alternatives considered

- Azure Container Registry in the persistent layer. Stays inside Azure and supports private images. It needs a role for the cluster to pull, and the tier and price were not read. It can be revisited if private images are needed.
- Azure Container Registry created and filled each session. The image would be rebuilt and pushed every time, which adds minutes to a session.
