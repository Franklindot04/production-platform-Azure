# ADR 0029: Give the sample service access to Key Vault with workload identity

- Status: proposed
- Date: 2026-11-09
- Issue: #42

## Context

ADR 0022 defined the persistent layer with a Key Vault that uses Azure RBAC and has no role assigned. The architecture document says pods use workload identity to read Key Vault and that no Azure credential is stored in the cluster. The sample service needs to read one secret. The cluster is destroyed after each session, and its OIDC issuer URL changes with each cluster. The node pool is small (ADR 0012).

## Decision

- The cluster enables the OIDC issuer, workload identity and the AKS Key Vault secrets provider add-on (the Secrets Store CSI driver). Secret rotation is off.
- The service reads the secret as a file that the add-on mounts. The service code does not call Key Vault and has no Azure SDK.
- The identity `pp-<env>-sample-service` is a user-assigned managed identity in the persistent root, because it outlives a session.
- The federated credential is in the session root, because it holds the issuer URL of the cluster. It is created and destroyed with the cluster. Its subject is `system:serviceaccount:apps:sample-service`, the namespace and service account of the chart and the gitops files. Its audience is `api://AzureADTokenExchange`. The session root finds the identity by name with a data source.
- Two roles on the vault:
  - Key Vault Secrets User for the sample service identity. It reads values and cannot change them.
  - Key Vault Secrets Officer for the principal that runs apply, so the maintainer can set the secret by hand. Issue #43 reviews roles.
- No identity ID, client ID or tenant ID is written in Git. They are read from the Terraform outputs at run time.
- The secret value is set by hand. It is never in Terraform and never in state, and Terraform creates no `azurerm_key_vault_secret`.
- The network rule on the vault is deferred. A deny-by-default rule would block Terraform runs from the maintainer's machine and the cluster's pods, and the outbound address of the cluster exists only during a session. The scan finding is accepted in `.trivyignore.yaml` (AZU-0013).

## Consequences

- No Azure credential is stored in the cluster or in the repository.
- The add-on adds pods to the cluster. Their requests are not measured, and their fit on the two-node pool is not verified.
- The chart, the session script and the kind check are not part of this record. They are planned. The chart's service account currently disables the token mount, so the chart change must allow the projected token.
- Rotation is off, so a changed secret value is read after the pod restarts.
- The vault is reachable from any network that has a role on it, until the network rule is added.
- Everything here is written and not applied. It is unverified until a live session.

## Alternatives considered

- Calling Key Vault from the service code with an Azure SDK. It adds a dependency to the service and needs the token exchange in code.
- The identity and credential both in the session root. The identity and its role would be destroyed and re-created each session.
- Both in the persistent root. The credential would need the issuer URL of a cluster that does not persist.
- A secret stored in the cluster by hand. It is lost with the cluster and needs a credential to be stored somewhere.
