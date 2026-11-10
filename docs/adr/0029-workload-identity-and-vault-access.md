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
- The chart has a `vaultSecret` block, off by default. When it is on, the chart adds the client ID annotation to the service account, a `SecretProviderClass`, the pod label `azure.workload.identity/use` and a CSI volume mounted read-only at `/mnt/secrets`. The token mount stays off in the service account and in the pod, because the driver gets the token from the kubelet. The values file in Git holds only the secret name `sample-service-secret`.
- The run-time path: the part `identity` of `session.sh bootstrap` reads the client ID and the vault name from the persistent root outputs and the tenant ID from the signed-in account. It sets them as Helm parameters, with `vaultSecret.enabled` true, on the Argo CD Application `sample-service`. The root Application ignores differences on `/spec/source/helm/parameters` of Applications and respects that setting when it syncs, so its self-heal does not remove the parameters.
- The secret value is set by hand. It is never in Terraform and never in state, and Terraform creates no `azurerm_key_vault_secret`.
- The network rule on the vault is deferred. A deny-by-default rule would block Terraform runs from the maintainer's machine and the cluster's pods, and the outbound address of the cluster exists only during a session. The scan finding is accepted in `.trivyignore.yaml` (AZU-0013).

## Consequences

- No Azure credential is stored in the cluster or in the repository.
- The add-on adds pods to the cluster. They fit on the two-node pool with the other tools (Session 1, `docs/sessions/session-1-results.md`).
- The pod does not start until the secret exists in the vault, because the mount fails. The maintainer sets the secret once (`infrastructure/README.md`).
- The chart, the session script part and the kind check are written. The kind check renders the chart and validates it. It does not mount a secret, because a kind cluster has no vault.
- Session 1 showed that the root Application leaves the parameters alone, and that the driver gets a token with the token mount off. Both sample service pods mounted the secret with no mount warnings.
- Rotation is off, so a changed secret value is read after the pod restarts.
- The vault is reachable from any network that has a role on it, until the network rule is added.
- The persistent resources (the identity and the Key Vault roles) are applied. The session resources (the cluster settings, the federated credential and the chart mount) were applied in Session 1 and destroyed with the session layer. The mount was checked there.

## Alternatives considered

- Calling Key Vault from the service code with an Azure SDK. It adds a dependency to the service and needs the token exchange in code.
- The identity and credential both in the session root. The identity and its role would be destroyed and re-created each session.
- Both in the persistent root. The credential would need the issuer URL of a cluster that does not persist.
- A secret stored in the cluster by hand. It is lost with the cluster and needs a credential to be stored somewhere.
