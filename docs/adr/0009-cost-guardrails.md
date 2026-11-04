# ADR 0009: Set cost guardrails and teardown policy

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

The project runs on a personal Azure subscription. The subscription is not created yet. If it is created, it is expected to be a free credit account. The credit amount, its duration, and what happens when it ends must be checked at sign-up. No monthly budget is set.

## Decision

- The cluster and everything that depends on it are created at the start of a work session and destroyed at the end with `terraform destroy`.
- Anything that must outlive a session lives in a separate persistent layer, and is kept small: state storage, Key Vault, the Azure Monitor and Log Analytics workspaces, and possibly the container registry.
- When a budget amount is set, create an Azure budget with alerts at fixed percentages, defined in Terraform. Until then, the amount is an open question.
- Use small node sizes and the fewest nodes that work.
- At the end of each session, check the resource group list in the portal or with the CLI for resources that were not destroyed.
- Tag every resource, so cost can be filtered by project and environment.

Assumptions:

- Only one environment runs at a time.
- Sessions are short enough that the credit lasts. This is not verified.

## Consequences

- Cost is mostly tied to session hours.
- Forgetting to destroy is the largest cost risk. The end-of-session check is the control, and it depends on the maintainer.
- Some resources, such as Key Vault with purge protection, hold their names after deletion. They stay in the persistent layer for that reason.
- Each session starts with a full create. The time this takes is measured and recorded, and it feeds the recovery work in Epic 7 (#7).

## Alternatives considered

- Leave the cluster running. Simpler, but cost grows with idle time.
- Stop the cluster instead of destroying it. Stopping removes compute cost for nodes but keeps other resources billing, and it does not exercise the rebuild.
