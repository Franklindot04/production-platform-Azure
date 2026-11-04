# bootstrap

The one-time setup of the Terraform state backend, written as an Azure CLI script. It is not a Terraform root and keeps no Terraform state. See [ADR 0004](../../docs/adr/0004-terraform-state-backend.md) and [ADR 0010](../../docs/adr/0010-environment-separation.md).

## What it creates

| Resource | Name |
|---|---|
| Resource group | `pp-shared-state-rg` in `northeurope` |
| Storage account | `ppsharedstate` plus a 6-character suffix drawn by the script |
| Blob container | `tfstate-<env>`, for example `tfstate-dev` |
| Role assignment | Storage Blob Data Contributor for the signed-in user, on the container |

Tags on the resource group and the storage account: `project=production-platform-azure`, `env=shared`, `managed-by=azure-cli`. The tag value differs from [ADR 0003](../../docs/adr/0003-region-and-naming-convention.md) because Terraform does not manage these resources.

Storage account settings:

| Setting | Value |
|---|---|
| SKU and kind | `Standard_LRS`, `StorageV2`, hot tier |
| Shared key access | off, so only Microsoft Entra ID can reach the data |
| Minimum TLS version | 1.2 |
| HTTPS only | on |
| Public blob access | off |
| Blob versioning | on |
| Blob soft delete | on, 14 days |
| Container soft delete | on, 14 days |

There is no network firewall and no resource lock.

## Prerequisites

- Azure CLI, signed in to the target subscription with `az login`.
- A role that can create resource groups, storage accounts and role assignments, such as Owner.

## Run it

```bash
./infrastructure/bootstrap/bootstrap.sh dev
```

The first argument is the environment (`dev`, `staging` or `prod`) and defaults to `dev`. A second argument runs one step: `check`, `group`, `account`, `protect`, `container`, `role` or `verify`.

| Step | What it does |
|---|---|
| `check` | Shows the subscription name and state. Stops if it is not enabled. |
| `group` | Creates the resource group. |
| `account` | Draws a name, checks it is free, creates the storage account. |
| `protect` | Turns on versioning and soft delete. |
| `container` | Creates `tfstate-<env>` through the Azure Resource Manager API. This needs no data role. |
| `role` | Assigns Storage Blob Data Contributor on the container to the signed-in user. |
| `verify` | Reads back the settings and tests data access. |

Each step skips what already exists, so the script can be run again. To add `staging` later, run it with `staging`: only the container and the role are new.

The script writes the account name to `.state-account-name` in this folder. The file is not committed. If it is lost, the script finds the account in the resource group.

Output is masked: any GUID is replaced with `xxxx`.

## Checks

`verify` runs these checks:

- Tags and location of the resource group and the storage account.
- Shared key access, public blob access, TLS version and HTTPS only on the storage account.
- Versioning and soft delete settings.
- The container exists, and the role assignment exists on it.
- A blob list with `--auth-mode login` succeeds. It is retried for up to 5 minutes, because a new role assignment can take a few minutes to apply.
- A blob list with `--auth-mode key` is refused.

## Use the backend

The account name is not committed. Pass it when initialising a root that uses the backend:

```bash
terraform init \
  -backend-config="resource_group_name=pp-shared-state-rg" \
  -backend-config="storage_account_name=$(cat infrastructure/bootstrap/.state-account-name)"
```

The root needs a `backend "azurerm"` block with `use_azuread_auth = true`, `container_name = "tfstate-dev"` and `key = "persistent.tfstate"`. No root has this block yet.

`terraform init` against an empty container writes an empty state file, `persistent.tfstate`, with no resources.

## Cost

The monthly cost is unknown. It has not been measured. The account holds a few small state files and their versions. It has no compute.

## Limits

- The storage account is shared by all environments. Losing it loses all state. Versioning and soft delete reduce that risk but do not remove it.
- Only the signed-in user gets a role. Roles for pipeline identities are planned.
- The script is not declarative. If a setting is changed in the portal, the script does not detect it. `verify` shows the current values.
