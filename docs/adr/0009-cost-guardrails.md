# ADR 0009: Set cost guardrails and teardown policy

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

The project runs on one Azure subscription. Cost is controlled by tagging every resource, by destroying the session layer after each session, and by a budget with alerts. The target subscription has a regional vCPU quota of 4 in `swedencentral`, which also limits how much compute can run.

## Decision

- The cluster and everything that depends on it are created at the start of a work session and destroyed at the end with `terraform destroy`.
- Anything that must outlive a session lives in a separate persistent layer, and is kept small: state storage, Key Vault, the Azure Monitor and Log Analytics workspaces, and possibly the container registry.
- Define an Azure budget with alerts at fixed percentages in Terraform. The amount and the percentages are set in the code.
- Use small node sizes and the fewest nodes that work. The target subscription has a regional vCPU quota of 4 (ADR 0003).
- At the end of each session, check the resource group list in the portal or with the CLI for resources that were not destroyed.
- Tag every resource, so cost can be filtered by project and environment.

Assumptions:

- Only one environment runs at a time. With a regional quota of 4 vCPU, a second cluster would use most or all of it.
- Sessions are short enough that cost stays within the budget. This is not verified.

## Consequences

- Cost is mostly tied to session hours.
- Forgetting to destroy is the largest cost risk. The end-of-session check is the control, and it depends on the maintainer.
- Some resources, such as Key Vault with purge protection, hold their names after deletion. They stay in the persistent layer for that reason.
- Each session starts with a full create. The time this takes is measured and recorded, and it feeds the recovery work in Epic 7 (#7).

## Alternatives considered

- Leave the cluster running. Simpler, but cost grows with idle time.
- Stop the cluster instead of destroying it. Stopping removes compute cost for nodes but keeps other resources billing, and it does not exercise the rebuild.
