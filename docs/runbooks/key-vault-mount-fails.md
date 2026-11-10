# Key Vault mount fails

## Trigger

Sample service pods stay in `ContainerCreating` because the Key Vault secret cannot be mounted (ADR 0029).

## Impact

The pods do not start, so the service has no ready pod. The chart mounts the secret `sample-service-secret` as a file at `/mnt/secrets` through the Secrets Store CSI driver, with workload identity. The kubelet cannot start the container until the mount works.

If the mount is not turned on (`vaultSecret.enabled` is false), the pods start without it and this runbook does not apply.

## First checks

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). It shows pods stuck in `ContainerCreating`.
2. `kubectl describe pod -n apps <pod name>` (planned, not run). The events show a `FailedMount` and the message from the driver. The message is the main clue.
3. `kubectl get application sample-service -n argocd -o jsonpath='{.spec.source.helm.parameters[*].name}{"\n"}'` (planned, not run). It shows the names of the Helm parameters and not their values. They should include the `vaultSecret` parameters that `session.sh bootstrap identity` sets.
4. `kubectl get secretproviderclass -n apps` (planned, not run). It shows whether `sample-service-vault` exists. Do not print it with `-o yaml` into a shared place: it holds the client ID, the tenant ID and the vault name.
5. `kubectl get serviceaccount sample-service -n apps -o jsonpath='{.metadata.annotations}{"\n"}'` (planned, not run). It shows whether the client ID annotation is present. The value is an identifier, so do not share the output.
6. `kubectl get csidriver secrets-store.csi.k8s.io` (planned, not run). It shows whether the driver is installed by the cluster add-on.
7. `az keyvault secret show --vault-name "$(terraform -chdir=infrastructure/environments/dev/persistent output -raw key_vault_name)" --name sample-service-secret --query id -o tsv` (planned, not run). It shows whether the secret exists. It prints the secret ID and not the value.

Unsure: step 7 needs a role that can read secrets on the vault. The maintainer has Key Vault Secrets Officer from the persistent root (ADR 0029), which allows reading secrets.

## Likely causes

All four are named in ADR 0029.

1. The secret `sample-service-secret` is not set in the vault. The pod does not start until it exists. The maintainer sets it by hand. Terraform never creates it.
2. A role is missing. The identity `pp-dev-sample-service` needs Key Vault Secrets User on the vault (`infrastructure/environments/dev/persistent/workload-identity.tf`). The roles are defined in the persistent root, which is applied.
3. The federated credential is missing. It is in the session root (`infrastructure/environments/dev/session/workload-identity.tf`). Its subject is `system:serviceaccount:apps:sample-service` and its audience is `api://AzureADTokenExchange`. It is created with the cluster. A credential bound to an earlier cluster does not match a new one.
4. The Application parameters are missing. `session.sh bootstrap identity` has not run, or the parameters were removed. Session 1 showed that the root Application leaves them alone (ADR 0029).

If the parameters are partly set while the mount is on, the chart fails to render with a message such as `vaultSecret.clientId must be set`. The pods are then not created, and the Application shows the error.

The driver, the workload identity webhook and the cluster add-on settings are in the session root. The driver pods fit on the two nodes (Session 1).

## Fix

1. Cause 1: set the secret with the command in [infrastructure/README.md](../../infrastructure/README.md), section "Set the Key Vault secret". It reads the value from a prompt. Do not put the value on a command line.
2. Cause 2: apply the persistent root so the role assignments exist. The apply is the maintainer's step and is not described here.
3. Cause 3: apply the session root so the federated credential exists for the current cluster. Run `./infrastructure/session.sh up` and read the plan, then `./infrastructure/session.sh up --apply` (planned, not run).
4. Cause 4: run `./infrastructure/session.sh bootstrap identity` (planned, not run). It sets the Helm parameters on the Application `sample-service` and turns the mount on.
5. The kubelet retries the mount. If a pod does not recover after the cause is fixed, delete it: `kubectl delete pod -n apps <pod name>` (planned, not run).

Unsure: that the kubelet retries by itself. This is the usual Kubernetes behaviour and is not shown in this repository.

## Verify

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods are ready.
2. `kubectl exec -n apps <pod name> -- ls /mnt/secrets` (planned, not run). It lists the file `sample-service-secret`. It does not print the value.

Unsure: step 2 depends on the image having a shell or `ls`. The image holds nothing else but the binary (`applications/sample-service/README.md`), so the command may fail even when the mount works. If it fails, a ready pod is the check.

## Rollback

Setting the secret, the parameters and the roles needs no rollback for the service. To turn the mount off, remove the `vaultSecret` parameters from the Application. The secret value stays in the vault.

## Source

ADR 0029, `helm/sample-service/templates/secretproviderclass.yaml`, `infrastructure/README.md`.

## Status

not exercised
