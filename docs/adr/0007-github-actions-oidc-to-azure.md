# ADR 0007: Authenticate GitHub Actions to Azure with OIDC

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

Pipelines need to log in to Azure to run Terraform and push images. A stored client secret is a long-lived credential. If it leaks, someone else can act as the pipeline until it is rotated. The repository is public, so secrets handling matters.

## Decision

- Use OpenID Connect federation between GitHub Actions and Microsoft Entra ID. Pipelines get a short-lived token at run time. No Azure password or client secret is stored in GitHub.
- Create a federated credential whose subject is limited to this repository and to specific branches or GitHub environments.
- Give the pipeline identity the lowest Azure role that works, scoped to resource groups, plus a data role on the state storage container.
- Pull request runs get read-only access, for `terraform plan`. Changes to infrastructure are applied from the maintainer's machine at first.

Assumption: applying from the maintainer's machine is acceptable at first, because sessions are started and ended by hand. Applying from a pipeline is a later decision.

## Consequences

- No client secret to rotate or leak.
- Needs permission to create an app registration or managed identity in the tenant. This should be available on a new personal tenant, and it is not checked yet.
- The federated credential subject must be set carefully. A loose subject lets other workflows or branches get a token.

## Alternatives considered

- Service principal with a client secret in GitHub secrets. Simple, but it is a stored long-lived credential.
- Self-hosted runners with a managed identity. More to run and pay for.
