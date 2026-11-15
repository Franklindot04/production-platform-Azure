# Live session 4: runbooks, node drain and the missing data alert

Status: planned. Nothing on this page has been run. Issue #141 holds this plan. The work it covers is in the v0.3.0 row of [plan.md](../plan.md): #46, #98, #89 and #136.

Goal: exercise the seven runbooks that are not yet exercised, try the node drain again (#98), run the destroy repeat against a failed destroy if one can be caused (#89), remove one node instance, run the network policy block experiment, test the alert for missing data (#136, [ADR 0033](../adr/0033-missing-data-alert.md)), and destroy everything.

Time box: 4 hours, counted from the start of `./infrastructure/session.sh up --apply` to the start of the teardown. [Session 2](session-2.md) used a box of about 2 hours with teardown at 1:45. [Session 3](session-3.md) started teardown one hour after the load started. This page has more experiments than either, and the alert test alone waits 15 minutes.

Rules are the same as in [Session 1](session-1.md) ([results](session-1-results.md)), [Session 2](session-2.md) ([results](session-2-results.md)) and [Session 3](session-3.md) ([results](session-3-results.md)): approved plans, masked output, no stored credentials.

Every command on this page is planned, not run.

## What is exercised

| Runbook | Experiment on this page | Status line today |
|---|---|---|
| [pod-not-ready.md](../runbooks/pod-not-ready.md) | 1 | not exercised |
| [argocd-drift.md](../runbooks/argocd-drift.md) | 2 | not exercised |
| [key-vault-mount-fails.md](../runbooks/key-vault-mount-fails.md) | 3 | not exercised |
| [image-pull-refused.md](../runbooks/image-pull-refused.md) | 4 | not exercised |
| [missing-request-data.md](../runbooks/missing-request-data.md) | 5 | not exercised |
| [network-policy-blocks-service.md](../runbooks/network-policy-blocks-service.md) | 6 | not exercised |
| [node-drain.md](../runbooks/node-drain.md) | 7 | exercised in Session 2. The drain did not complete (#98) |
| [session-leftovers.md](../runbooks/session-leftovers.md) | Teardown | not exercised |

The node instance removal (experiment 8) and the destroy repeat (#89) have no runbook of their own.

## Before the session

1. This plan is merged and `main` is clean.
2. `./infrastructure/session.sh check` exits 0 and vCPU use is 0 of 4 ([session-leftovers.md](../runbooks/session-leftovers.md) explains the output).
3. The persistent layer is applied: the rule group `pp-dev-slo-alerts`, the action group and the Key Vault exist. The alert email address is set in `TF_VAR_alert_email` for any persistent apply, and it is not written to a file (`infrastructure/README.md`).
4. The authorized range is in `TF_VAR_api_authorized_ip_ranges` and the admin group is in `TF_VAR_cluster_admin_group_object_id`. Both are set at run time.
5. The secret `sample-service-secret` is set in the vault, so the pods can mount it ([key-vault-mount-fails.md](../runbooks/key-vault-mount-fails.md), Fix step 1).
6. k6 is installed on the maintainer's machine (`tests/load/README.md`).
7. The budget of `dev` and its spend are read before the session with the commands in [cost.md](../cost.md). The cost per hour of cluster time is not calculated there.
8. The two facts in the list at the end of this page are confirmed, or the steps that use them are replaced.

## Run sheet

Times are not promised. L is the moment the sample service is healthy after the bootstrap. Each step ends with a stop rule.

| Step | Action | Command | Record |
|---|---|---|---|
| Preflight | Check that nothing remains | `./infrastructure/session.sh check` (planned, not run) | The exit code |
| Rebuild | Create the session layer | `./infrastructure/session.sh up`, read the plan, then `./infrastructure/session.sh up --apply`, then `./infrastructure/session.sh bootstrap` (planned, not run) | The time of each step, and L. The alert rule group `pp-dev-session-alerts` is part of the apply |
| L | Record the start of metrics | Run `monitoring/prometheus/request-rate.promql` in the Prometheus explorer of `pp-dev-amw` until a `/readyz` series appears (planned, not run) | The time from L to the first `/readyz` series |
| 1 | Delete a pod | See experiment 1 | See experiment 1 |
| 2 | Edit by hand | See experiment 2 | See experiment 2 |
| 3 | Key Vault mount | See experiment 3 | See experiment 3 |
| 4 | Image pull | See experiment 4 | See experiment 4 |
| 5 | Missing data alert | See experiment 5 | See experiment 5 |
| 6 | Network policy block | See experiment 6 | See experiment 6 |
| 7 | Node drain | See experiment 7 | See experiment 7 |
| 8 | Remove a node instance | See experiment 8 | See experiment 8 |
| Wrap up | Cost snapshot, saved output | The commands in [cost.md](../cost.md) (planned, not run) | Files saved |
| Teardown | Destroy and check | See Teardown | The output of `check` |

Auto sync on `root` and `cluster-rules` is switched off in experiment 5 and back on at the end of experiment 6.

The order puts the cheap experiments first. Experiments 7 and 8 come last, because both use the room that the two nodes have, and a failure there can leave pods pending. Every stop rule below ends in the teardown.

## Experiments

Each experiment has five fields: trigger, expected result, what is recorded, the runbook step it exercises, and the stop rule. An expected result is a hypothesis. It is not a result.

### 1. Delete a pod

1. Trigger: `kubectl delete pod -n apps <pod name>` (planned, not run).
2. Expected: the other pod serves, and a new pod is ready within the probe time. [Session 2 results](session-2-results.md) record a pod delete with 1 of 90 probes failed. The steps of the runbook were not run then.
3. Recorded: the First checks 1 to 4 of [pod-not-ready.md](../runbooks/pod-not-ready.md) (`kubectl get pods`, `describe pod`, `get events`, `get endpoints`), the time until both pods are ready, and Verify step 1 and step 2.
4. Runbook step: First checks 1 to 4, Fix step 1 and step 3, Verify 1 and 2.
5. Stop rule: if both pods are not ready again after the checks, go to the teardown.

### 2. Edit a resource by hand

1. Trigger: `kubectl scale deployment sample-service -n apps --replicas=3` (planned, not run). The chart sets `replicaCount` to 2 in `helm/sample-service/values.yaml`, and Argo CD self-heal on the Application `sample-service` reverts the change. The quota of `apps` allows the third pod: three pods request 75m CPU and 96Mi memory against 500m and 1Gi, and the quota allows 20 pods (`kubernetes/quotas/apps.yaml`).
2. Expected: the Application goes `OutOfSync` and back to `Synced`, and the value returns to the one in Git ([argocd-drift.md](../runbooks/argocd-drift.md)). A change on `main` was synced in up to about 3 minutes in Session 1.
3. Recorded: `kubectl get application sample-service -n argocd -w`, the time until `Synced`, the time until the Deployment shows 2 replicas again, and the value read in Verify step 2.
4. Runbook step: First checks 1 to 3, Fix step 1, Verify 1 and 2. Fix step 3 (the refresh annotation) is run only if the Application stays `OutOfSync`.
5. Stop rule: if the Application stays `OutOfSync` after Fix step 3, record it and go to the teardown.

### 3. Key Vault mount

1. Trigger: none. No fault is staged on this page. The read-only First checks 3 to 6 of [key-vault-mount-fails.md](../runbooks/key-vault-mount-fails.md) run on the healthy cluster.
2. Expected: the checks show the Helm parameter names, the `SecretProviderClass`, the service account annotation and the driver. Check 7 shows the secret ID and not the value.
3. Recorded: for each check, whether the output matches what the runbook says. Where a command differs, the line to change in the runbook.
4. Runbook step: First checks 1 to 7. Fix steps are not run, because no fault is staged. Verify step 2 (`ls /mnt/secrets`) is run, and its result is recorded, because the runbook says it may fail on this image.
5. Stop rule: the first pass changes nothing, so there is nothing to stop.

### 4. Image pull

1. Trigger: none in the first pass. The read-only First checks 1 to 4 of [image-pull-refused.md](../runbooks/image-pull-refused.md) run on the healthy cluster. No refusal is staged on this page. [bad-image-tag.md](../runbooks/bad-image-tag.md) was exercised in Session 2 with a bad tag.
2. Expected: the checks show the image and the tag that the pods asked for, and when the tag changed. Check 5 (`docker manifest inspect`) is marked unsure in the runbook. It is run only if `docker` is available on the maintainer's machine.
3. Recorded: for each check, whether the output matches the runbook, and whether check 5 ran.
4. Runbook step: First checks 1 to 5. Fix steps are not run.
5. Stop rule: the first pass changes nothing, so there is nothing to stop.

### 5. Missing data alert

1. Trigger: stop the scrape of the sample service, so that the `/readyz` series stops arriving in the workspace. Three steps, each planned, not run:
   1. Switch off auto sync on the Application `root`: `kubectl patch application root -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'` (planned, not run).
   2. Switch off auto sync on the Application `cluster-rules`: `kubectl patch application cluster-rules -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'` (planned, not run). `root` goes first, because `root` restores the sync policy of `cluster-rules` from `gitops/dev/apps` while its own auto sync is on.
   3. Delete the policy: `kubectl delete networkpolicy allow-metrics-scrape -n apps` (planned, not run). The policy allows ingress to port 8081 of the sample service pods from the metrics agent pods (`rsName: ama-metrics` in `kube-system`), so deleting it stops the scrape of the sample service (`kubernetes/network-policies/apps.yaml`, `helm/sample-service/templates/podmonitor.yaml`).
2. Expected (a hypothesis): once no sample has been seen in the 5 minute range, the expression `absent_over_time(http_requests_total{route="/readyz"}[5m])` can return a value. [MissingRequestData](../adr/0033-missing-data-alert.md) (severity 2) fires after `for` of `PT15M`, plus the evaluation interval, which `infrastructure/environments/dev/session/alerts.tf` sets to `PT1M`. Calculated from these values, the earliest firing is 5 + 15 + 1 minutes after the last sample. The mail arrives through the action group. The alert resolves by itself (`time_to_resolve` is `PT10M` in `alerts.tf`).
3. Recorded:
   - the time from L to the first `/readyz` series (from the run sheet), because a new cluster reached Healthy in 772 seconds in [Session 2 results](session-2-results.md) and the wait is 15 minutes;
   - whether the alert fired before the data was stopped (at session start);
   - the time of the delete, the time the alert fired, the time the mail arrived and the time the alert resolved.
4. Runbook step: First checks 1 to 5 of [missing-request-data.md](../runbooks/missing-request-data.md), Fix step 2 (it points to [network-policy-blocks-service.md](../runbooks/network-policy-blocks-service.md)) and Verify 1 and 2. The experiment removes a policy and holds auto sync off, so the restore is `kubectl apply -f kubernetes/network-policies/apps.yaml` (planned, not run) and not the steps of that runbook.
5. Stop rule: the wait margin is 10 minutes past the earliest firing time given in Expected. The margin is a value chosen for this plan. If the alert has not fired by then, record it, restore the policy with `kubectl apply -f kubernetes/network-policies/apps.yaml` (planned, not run), and go on to experiment 6 with auto sync still off. If it fired, restore the policy the same way once the firing and the mail are recorded, then record the resolution, which needs the data back. If the alert fired at session start, the `for` value is raised in a later change ([ADR 0033](../adr/0033-missing-data-alert.md)).

### 6. Network policy block

1. Trigger: with auto sync still off from experiment 5, `kubectl delete networkpolicy allow-ingress-controller -n apps` (planned, not run). A NetworkPolicy cannot deny by itself, because `default-deny` and the allow policies add up, so the block is the removal of an allow policy. `allow-ingress-controller` allows ingress to port 8080 of the sample service pods from the namespace `app-routing-system`, which is the path of the managed ingress (`kubernetes/network-policies/apps.yaml`).
2. Expected: requests through the ingress stop reaching the pods. The runbook records that probe traffic was not blocked by the default-deny policy in Session 1. One fact is not known: whether an alert fires when no request reaches the pods.
3. Recorded: the state of the pods and of the endpoints, the result of `SCENARIO=smoke` through the ingress, and whether MissingRequestData or a burn-rate alert fires.
4. Runbook step: First checks 1 to 6 and Verify 1 to 3 of [network-policy-blocks-service.md](../runbooks/network-policy-blocks-service.md). Its Fix step 1 deletes a policy that was added by hand. This experiment removes a policy instead, so the fix is `kubectl apply -f kubernetes/network-policies/apps.yaml` (planned, not run). Fix step 2 does not apply, because auto sync is off. Fix step 4 (do not delete `default-deny`) applies.
5. Stop rule: restore the policy with `kubectl apply -f kubernetes/network-policies/apps.yaml` (planned, not run). Then switch auto sync back on with `kubectl patch application root -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'` (planned, not run), the block that `gitops/dev/root-application.yaml` holds, so that `root` restores `cluster-rules` from Git. Check with `kubectl get application -n argocd` (planned, not run) that `root` and `cluster-rules` show auto sync again. If the pods are not ready after that, go to the teardown.

### 7. Node drain

1. Trigger: `kubectl drain <node name> --ignore-daemonsets --delete-emptydir-data --timeout=300s` on the node that holds a sample service pod (planned, not run). The flags were accepted in Session 2.
2. Before the drain: measure the CPU and memory requests against what each node can allocate, with `kubectl describe nodes` (planned, not run). In Session 2 the other node showed 99% CPU requested after the drain and the uncordon, and seven pods stayed Pending (#98): one sample service replica, three Argo CD pods, the second metrics-server pod, retina-agent and the collector. The disruption budget of metrics-server blocked its eviction.
3. Decision rule, applied before the drain. The decision itself is not made on this page.
   1. Add the CPU requests of the pods that the drain would move (the pods that are not part of a DaemonSet) to the requests already on the other node.
   2. If the sum is above what the other node can allocate, the drain cannot complete on two nodes. Then either lower the requests that the chart values allow (`helm/sample-service/values.yaml` sets 25m CPU and 32Mi memory for the sample service; the requests of the other pods are set in their own charts), or accept the result for `dev` and write it in [node-drain.md](../runbooks/node-drain.md).
   3. If the sum fits, run the drain and record whether it completes.
   4. A change of requests is a pull request, made after the session. It is not made during the session.
4. Expected: stated after the measurement, in the results page. It is not stated here.
5. Recorded: the requests per node before the drain, the exit code of the drain, the pods that stay Pending and why, the time until the pods are placed after `kubectl uncordon <node name>`, and the decision that the rule leads to.
6. Runbook step: First checks 1 to 5, Fix step 1 to step 3, Verify 1 to 3.
7. Stop rule: after the drain and the uncordon, if pods are still Pending after the checks, delete them as in Fix step 3. If they stay Pending, go to the teardown. Do not run experiment 8.

### 8. Remove a node instance

1. Trigger, in three steps, each planned, not run:
   1. `kubectl get nodes` reads the node names (planned, not run).
   2. `az aks nodepool delete-machines --resource-group pp-dev-session-rg --cluster-name pp-dev-aks --name system --machine-names <node name>` (planned, not run), with `<node name>` taken from step 1. The removal goes through AKS. The node resource group `pp-dev-aks-nodes-rg` is not changed directly. The resource group, the cluster name and the pool name are in `infrastructure/environments/dev/session/main.tf`.
   3. `az aks nodepool show --resource-group pp-dev-session-rg --cluster-name pp-dev-aks --name system --query count -o tsv` (planned, not run) reads the node count of the pool.
2. Expected (a hypothesis): the removed node is no longer in `kubectl get nodes`, and the pods that ran on it are placed on the other node as far as its requests allow. Whether AKS creates a replacement node is not known.
3. Recorded: the command used, the node count of the pool, `kubectl get nodes`, the state of the pods, and, if the count is 1, the restore command with the time until the new node is `Ready`.
4. Restore, only if the count is 1: `az aks nodepool scale --resource-group pp-dev-session-rg --cluster-name pp-dev-aks --name system --node-count 2` (planned, not run). Two nodes of 2 vCPU stay within the regional quota of 4 vCPU ([ADR 0003](../adr/0003-region-and-naming-convention.md)).
5. Runbook step: none. The step is new. If it works, a short runbook is a later change.
6. Stop rule: this is the last experiment. If the cluster does not recover, go to the teardown at once. [Session 2](session-2.md) planned the step as optional, because all 4 vCPU are in use. The removal frees 2 vCPU before any restore.

## Teardown

1. `./infrastructure/session.sh down` shows the destroy plan (planned, not run).
2. The destroy repeat test (#89), run once, before the first destroy of the session. Four steps, each planned, not run:
   1. Create a lock before the destroy: `az lock create --name session-test-lock --lock-type CanNotDelete --resource-group pp-dev-session-rg` (planned, not run).
   2. `./infrastructure/session.sh down --yes` (planned, not run). Expected (a hypothesis, from the header of `infrastructure/session.sh`): the destroy fails on the locked resources, the script waits for `PP_DESTROY_RETRY_WAIT` and runs once more, and that run fails as well.
   3. Remove the lock: `az lock delete --name session-test-lock --resource-group pp-dev-session-rg` (planned, not run).
   4. `./infrastructure/session.sh down --yes` again, then `./infrastructure/session.sh check` (planned, not run).

   Recorded: whether the first destroy failed, the error text with identifiers masked, whether the second run recovered, and the exit code of `check`. The session layer bills while the lock is in place, so step 3 follows step 2 at once.
3. `./infrastructure/session.sh down --yes` destroys the session root. If the test in item 2 was run, step 4 of that test is this destroy and the check that follows. If the destroy fails, it waits and runs once more. The wait is set by `PP_DESTROY_RETRY_WAIT`, in seconds (planned, not run, documented in the header of `infrastructure/session.sh`).
4. `./infrastructure/session.sh check` (planned, not run). The session ends when it exits 0.
5. If a step fails or `check` exits 1, follow [session-leftovers.md](../runbooks/session-leftovers.md): read the `== result` lines, run `down` and `down --yes` again, and repeat `check`. A state lock error and a public IP that the load balancer still holds (`PublicIPAddressCannotBeDeleted`) are named there.
6. The destroy repeat (#89) is exercised by the test in item 2, or by a destroy that fails by itself. Record whether the repeat ran and whether it recovered. If no destroy fails, the repeat stays untested and #89 stays open.
7. The runbook [session-leftovers.md](../runbooks/session-leftovers.md) is exercised for its First checks (`check`, the `== result` lines and `down`). Its Fix steps are exercised only if something remains.

A teardown that is not finished is the largest cost risk ([ADR 0009](../adr/0009-cost-guardrails.md)). Teardown starts when the time box of 4 hours ends, whatever is unfinished.

## What is recorded

1. The rebuild time of each step, and the time from L to the first `/readyz` series.
2. For each experiment: the hypothesis, the result, the time to recover, and where the runbook steps did not match what was seen.
3. For the alert for missing data: the times of the data stop, the firing, the mail and the resolution, and whether it fired at session start.
4. For the drain: the requests per node before it, the exit code, the pods that stayed Pending, and the decision from the rule.
5. Anything done by hand.
6. Whether the destroy repeat ran, and whether it recovered (#89).
7. The cost snapshot, with the commands in [cost.md](../cost.md).

## After the session

Planned, not done:

1. `session.sh check` exits 0.
2. The results go into `docs/sessions/session-4-results.md` in a pull request.
3. The status line of each exercised runbook and its row in the [runbook index](../runbooks/README.md) change to what was run. A runbook that was only partly run says which steps were not run, as [latency-burn.md](../runbooks/latency-burn.md) does.
4. The v0.3.0 row in [plan.md](../plan.md) lists what is done and what is not.
5. #98, #89, #46 and #136 close only for what was run.
6. A release is created only when the maintainer says.

## To be confirmed

Each item below is a fact that the repository does not give. It is confirmed before the session, or the step that uses it is replaced.

1. Whether `az aks nodepool delete-machines` takes the node name as the machine name on the pool `system` (experiment 8).
2. Whether the account that runs the session can create and delete a resource group lock (Teardown, item 2).
