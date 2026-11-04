# ADR 0003: Choose Azure region and resource naming convention

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

Every Azure resource is created in a region, and most resource names cannot be changed after creation. Names also need to be readable in the portal and in billing reports. Some names, such as storage accounts and container registries, must be unique across all of Azure and cannot contain hyphens.

The target subscription has a regional vCPU quota of 4 in `swedencentral`. This limits the node pools of any cluster in the region. See section 7 of the architecture document.

## Decision

- Workload region: `swedencentral`. The cluster and the other workload resources go in this region.
- State storage region: `northeurope`. The state storage account stays there (ADR 0004). State in a different region from the workloads is acceptable.
- Prefix: `pp`.
- Pattern for resources that allow hyphens: `pp-<env>-<resource>`, for example `pp-dev-aks` or `pp-dev-session-rg`.
- Pattern for resources that do not allow hyphens or need global uniqueness: `pp<env><resource><suffix>`, for example `ppdevacr` plus a short random suffix. Terraform creates the suffix. The state storage account is the exception: the bootstrap script draws its 6-character suffix (ADR 0004).
- `<env>` is `dev`, `staging` or `prod`. The state storage serves all environments and uses `shared` in that position. The environment model is in ADR 0010.
- Every resource gets these tags where Azure allows tags: `project=production-platform-azure`, `env=<env>`, `managed-by=terraform`. The resources made by the bootstrap script (ADR 0004) carry `managed-by=azure-cli`, because Terraform does not manage them.

Assumptions:

- The region name does not appear in resource names, because the workloads use one region. If a second workload region is added, this ADR is superseded.
- The workload region offers the VM sizes the project needs. ADR 0012 records the sizes.

## Consequences

- Names are short and sortable by environment.
- A change of region later means destroying and re-creating resources. That is cheap here, because the cluster is already destroyed after each session. It is not cheap for anything kept between sessions, such as state storage.
- A single workload region means no regional failover. This is a stated non-goal in the architecture document.

## Alternatives considered

- Put the region in every name, for example `pp-dev-ne-aks`. Longer names and no benefit while there is one region.
- `westeurope`. Not chosen. No technical reason was found. The choice was made by the maintainer.
- `northeurope` for workloads. Not chosen. It is used for the state storage account only. The VM size availability behind the choice of `swedencentral` is in ADR 0012.
- Let Terraform generate all names. Harder to read in the portal.
