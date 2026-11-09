# Pod not ready

## Trigger

A pod of the sample service in the namespace `apps` is deleted, is not ready, or does not start. Session 2 experiment 1 deletes a pod on purpose.

## Impact

The chart runs 2 replicas and a PodDisruptionBudget with `minAvailable: 1`. With one pod not ready, the other pod serves all traffic. With both not ready, the Service has no endpoint. The hypothesis of experiment 1 is that traffic continues and a new pod is ready within the probe time. That is not tested.

The probes in `helm/sample-service/templates/deployment.yaml`:

| Probe | Path | Period | Failures before action |
|---|---|---|---|
| Readiness | `/readyz` | 5 seconds | 2 |
| Liveness | `/healthz` | 10 seconds | 3 |

`/readyz` returns 503 after the process gets a termination signal. `SHUTDOWN_DELAY` is 5 seconds.

## First checks

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows the state, the restarts, the age and the node of each pod.
2. `kubectl describe pod -n apps <pod name>` (planned, not run). The events at the end show probe failures, scheduling failures, image pull errors and mount errors.
3. `kubectl get events -n apps --sort-by=.lastTimestamp` (planned, not run). It shows recent events of the namespace, including failures to create pods.
4. `kubectl get endpoints sample-service -n apps` (planned, not run). It shows which pod addresses the Service sends to.
5. `kubectl logs -n apps <pod name>` (planned, not run). It shows the log of the pod. Add `--previous` for a container that restarted.
6. `kubectl get resourcequota -n apps` (planned, not run). It shows use against the quota of the namespace (`kubernetes/quotas/apps.yaml`).

## Likely causes

- The pod was deleted and the new pod has not passed its readiness probe yet. This is experiment 1 and needs no fix.
- The image cannot be pulled. See [image-pull-refused.md](image-pull-refused.md) and [bad-image-tag.md](bad-image-tag.md).
- The pod stays in `ContainerCreating` because the secret mount fails. See [key-vault-mount-fails.md](key-vault-mount-fails.md).
- A network policy blocks the probes. See [network-policy-blocks-service.md](network-policy-blocks-service.md).
- The pod is pending because the nodes have no room. See [node-drain.md](node-drain.md).
- The quota of `apps` is used up (500m CPU and 1Gi memory of requests, 20 pods). The events show a failure to create the pod.
- The namespace `apps` enforces the restricted Pod Security profile. A change to the pod spec that breaks the profile is refused when the pod is created. The events of the ReplicaSet show it.

Other causes are not known from the repository.

## Fix

1. For a deleted pod, wait. Watch with `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -w` (planned, not run). It shows the new pod move to ready.
2. For any other cause, follow the runbook named above.
3. To start a pod again, delete it: `kubectl delete pod -n apps <pod name>` (planned, not run). The Deployment creates a new one.
4. Do not edit the Deployment with `kubectl`. Self-heal reverts it. See [argocd-drift.md](argocd-drift.md).

## Verify

1. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service` (planned, not run). Both pods show `1/1` ready.
2. `kubectl get endpoints sample-service -n apps` (planned, not run). Both pod addresses are listed.
3. `SCENARIO=smoke BASE_URL=http://<ingress address> k6 run tests/load/sample-service.js` (planned, not run). All checks pass (`tests/load/README.md`).

## Rollback

Deleting a pod needs no rollback. Reverse a change in Git with a revert pull request.

## Source

Session 2 experiment 1, `helm/sample-service/templates/deployment.yaml`, `helm/sample-service/templates/pdb.yaml`.

## Status

not exercised
