# ADR 0004: Use Azure Storage as the Terraform state backend

- Status: proposed
- Date: 2026-11-04
- Issue: #15

## Context

Terraform needs a place to keep state. The cluster is created and destroyed each session, so state must outlive it. State can contain sensitive values, so access has to be limited. Local state is not an option once pipelines run Terraform.

## Decision

- Store state in an Azure Storage account using the `azurerm` backend, with one blob container per environment, named `tfstate-<env>`.
- Two state files per environment, one per layer, with the keys `persistent.tfstate` and `session.tfstate` in each container. The layers are described in the architecture document.
- Authenticate with Microsoft Entra ID, not account keys. Shared key access on the storage account is turned off.
- Turn on blob versioning and soft delete, so an overwritten or deleted state file can be recovered.
- Rely on blob lease locking, which the backend provides, to stop two runs from writing at once.
- The storage account is created once by a bootstrap step that is run by hand. That step is the only place that uses local state, and it is documented when it is written.

Assumptions:

- One storage account serves all environments. This is an assumption, recorded in ADR 0010.
- The bootstrap uses the Azure CLI.

## Consequences

- State survives cluster teardown.
- A small, steady storage cost is expected. The amount is not estimated here.
- The bootstrap step is a manual exception to "everything is Terraform". It is written down so it can be repeated.
- Losing the storage account loses state. Versioning and soft delete reduce that risk but do not remove it.

## Alternatives considered

- HCP Terraform. Needs another account and service. Not needed for a single maintainer.
- Local state committed to the repository. State can hold secrets, and it does not work with pipelines.
- One storage account per environment. Stronger separation. Not chosen in ADR 0010, because there is one maintainer and a container per environment already separates access to state.
