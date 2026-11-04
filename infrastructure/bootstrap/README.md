# bootstrap

Planned. Will hold the one-time setup of the Terraform state backend: the `pp-shared-state-rg` resource group, the `ppsharedstate` storage account and the `tfstate-dev` container.

This is the only root that uses local state. See [ADR 0004](../../docs/adr/0004-terraform-state-backend.md) and [ADR 0010](../../docs/adr/0010-environment-separation.md).

The root has version constraints only. It defines no resources yet.
