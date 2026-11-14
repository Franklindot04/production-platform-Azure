# Live session 4: runbooks, node drain and the missing data alert

Status: planned. Nothing on this page has been run. Issue #141 holds this plan. The work it covers is in the v0.3.0 row of [plan.md](../plan.md): #46, #98, #89 and #136.

Goal: exercise the seven runbooks that are not yet exercised, try the node drain again (#98), run the destroy repeat against a failed destroy if one can be caused (#89), remove one node instance, run the network policy block experiment, test the alert for missing data (#136, [ADR 0033](../adr/0033-missing-data-alert.md)), and destroy everything.

Time box: to be confirmed. [Session 2](session-2.md) used a box of about 2 hours with teardown at 1:45. [Session 3](session-3.md) started teardown one hour after the load started. This page has more experiments than either, and the alert test alone waits 15 minutes.

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
8. The commands marked "to be confirmed" in the list at the end of this page are confirmed or replaced.

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

1. Trigger: a hand edit of the Deployment `sample-service` with `kubectl` (command to be confirmed). The expected revert is by Argo CD self-heal.
2. Expected: the Application goes `OutOfSync` and back to `Synced`, and the value returns to the one in Git ([argocd-drift.md](../runbooks/argocd-drift.md)). A change on `main` was synced in up to about 3 minutes in Session 1.
3. Recorded: `kubectl get application sample-service -n argocd -w`, the time until `Synced`, and the value read in Verify step 2.
4. Runbook step: First checks 1 to 3, Fix step 1, Verify 1 and 2. Fix step 3 (the refresh annotation) is run only if the Application stays `OutOfSync`.
5. Stop rule: if the Application stays `OutOfSync` after Fix step 3, record it and go to the teardown.

### 3. Key Vault mount

1. Trigger: none. A fault is not staged in the first pass. The read-only First checks 3 to 6 of [key-vault-mount-fails.md](../runbooks/key-vault-mount-fails.md) run on the healthy cluster. A way to stage a fault is to be confirmed.
2. Expected: the checks show the Helm parameter names, the `SecretProviderClass`, the service account annotation and the driver. Check 7 shows the secret ID and not the value.
3. Recorded: for each check, whether the output matches what the runbook says. Where a command differs, the line to change in the runbook.
4. Runbook step: First checks 1 to 7. Fix steps are not run unless a fault is staged. Verify step 2 (`ls /mnt/secrets`) is run, and its result is recorded, because the runbook says it may fail on this image.
5. Stop rule: the first pass changes nothing, so there is nothing to stop.

### 4. Image pull

1. Trigger: none in the first pass. The read-only First checks 1 to 4 of [image-pull-refused.md](../runbooks/image-pull-refused.md) run on the healthy cluster. A way to stage a refusal is to be confirmed. [bad-image-tag.md](../runbooks/bad-image-tag.md) was exercised in Session 2 with a bad tag.
2. Expected: the checks show the image and the tag that the pods asked for, and when the tag changed. Check 5 (`docker manifest inspect`) is marked unsure in the runbook. It is run only if `docker` is available on the maintainer's machine.
3. Recorded: for each check, whether the output matches the runbook, and whether check 5 ran.
4. Runbook step: First checks 1 to 5. Fix steps are not run.
5. Stop rule: the first pass changes nothing, so there is nothing to stop.

### 5. Missing data alert

1. Trigger: stop the `/readyz` series of the sample service in the workspace. The command is to be confirmed. Two candidates are named here without a command:
   - Remove the path of the metrics scrape, the policy `allow-metrics-scrape` in `kubernetes/network-policies/apps.yaml`. Argo CD restores a policy that is in Git ([network-policy-blocks-service.md](../runbooks/network-policy-blocks-service.md)), so the revert would have to be held back. How is to be confirmed.
   - Stop the pods. Argo CD self-heal and the Deployment replace them.
2. Expected: [MissingRequestData](../adr/0033-missing-data-alert.md) (severity 2, `for` of `PT15M`) fires after the series has been absent for the 15 minute wait, and the mail arrives through the action group. It resolves by itself (`time_to_resolve` is `PT10M` in `infrastructure/environments/dev/session/alerts.tf`). The expression is `absent_over_time(http_requests_total{route="/readyz"}[5m])`.
3. Recorded:
   - the time from L to the first `/readyz` series (from the run sheet), because a new cluster reached Healthy in 772 seconds in [Session 2 results](session-2-results.md) and the wait is 15 minutes;
   - whether the alert fired before the data was stopped (at session start);
   - the time the data stopped, the time the alert fired, the time the mail arrived and the time the alert resolved.
4. Runbook step: all First checks of [missing-request-data.md](../runbooks/missing-request-data.md), Fix step 1 and step 2, Verify 1 and 2.
5. Stop rule: if the alert has not fired when the series has been absent for the wait plus a margin (the margin is to be confirmed), record it, restore the data and go on to experiment 6. If the alert fired at session start, the `for` value is raised in a later change ([ADR 0033](../adr/0033-missing-data-alert.md)).

### 6. Network policy block

1. Trigger: apply a policy that blocks the sample service. The repository has no manifest for it, and which policy is applied is not known ([network-policy-blocks-service.md](../runbooks/network-policy-blocks-service.md)). The manifest is to be confirmed and is written before the session.
2. Expected: the probes of the pods and the requests through the ingress change as the policy selects. One fact is not known: whether an alert fires when no request reaches the pods. The runbook records that probe traffic was not blocked by the default-deny policy in Session 1.
3. Recorded: the state of the pods and of the endpoints, the result of `SCENARIO=smoke` through the ingress, and whether MissingRequestData or a burn-rate alert fires.
4. Runbook step: First checks 1 to 6, Fix step 1 and step 4, Verify 1 to 3.
5. Stop rule: delete the policy (Fix step 1) before the next experiment. If the pods are not ready after that, go to the teardown.

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

1. Trigger: remove one node instance of the node pool and watch AKS repair it. The command is to be confirmed. The repository names no command for it. [Session 2](session-2.md) planned it as optional, because all 4 vCPU are in use and a retry can fail.
2. Expected: AKS creates a replacement instance, and the pods return. Stated as a hypothesis.
3. Recorded: the command used, the time until the node is `Ready`, and the state of the pods.
4. Runbook step: none. The step is new. If it works, a short runbook is a later change.
5. Stop rule: this is the last experiment. If the cluster does not recover, go to the teardown at once.

## Teardown

1. `./infrastructure/session.sh down` shows the destroy plan (planned, not run).
2. `./infrastructure/session.sh down --yes` destroys the session root. If the destroy fails, it waits and runs once more. The wait is set by `PP_DESTROY_RETRY_WAIT`, in seconds (planned, not run, documented in the header of `infrastructure/session.sh`).
3. `./infrastructure/session.sh check` (planned, not run). The session ends when it exits 0.
4. If a step fails or `check` exits 1, follow [session-leftovers.md](../runbooks/session-leftovers.md): read the `== result` lines, run `down` and `down --yes` again, and repeat `check`. A state lock error and a public IP that the load balancer still holds (`PublicIPAddressCannotBeDeleted`) are named there.
5. The destroy repeat (#89) is exercised only if a destroy fails. A way to cause a failed destroy on purpose is to be confirmed. Record whether the repeat ran and whether it recovered. If no destroy fails, the repeat stays untested and #89 stays open.
6. The runbook [session-leftovers.md](../runbooks/session-leftovers.md) is exercised for its First checks (`check`, the `== result` lines and `down`). Its Fix steps are exercised only if something remains.

A teardown that is not finished is the largest cost risk ([ADR 0009](../adr/0009-cost-guardrails.md)). Teardown starts at the stop point of the time box, whatever is unfinished.

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

Each item below is a command or a value that the repository does not give. It is confirmed or replaced before the session.

1. The time box and the stop point for teardown.
2. The hand edit of experiment 2 (the `kubectl` command and the field).
3. A way to stage a Key Vault mount fault (experiment 3), if a second pass is wanted.
4. A way to stage an image pull refusal (experiment 4), if a second pass is wanted.
5. The command that stops the `/readyz` series for experiment 5, and how Argo CD is held back from restoring it.
6. The margin to wait after the 15 minute wait in experiment 5.
7. The manifest of the blocking policy for experiment 6.
8. The command that removes a node instance (experiment 8).
9. A way to cause a failed destroy (#89).
