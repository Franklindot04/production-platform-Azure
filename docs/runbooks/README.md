# Runbooks

A runbook is a short procedure for one failure that the repository already names: an alert, a failure experiment or a known setup problem. It says how to recognise the failure, what to check, how to fix it and how to tell that it is fixed.

Issue #46. The incident process and the postmortem template are issue #47 and are not here.

## Status

Nothing has been exercised yet. No live session has run. Every runbook is written from the repository files and from the experiment list in [Session 2](../sessions/session-2.md). Each one has the status `not exercised`.

- `not exercised`: written from the code, never run in a session.
- `exercised in <session>`: run in that session, with the date and the result recorded in that session's record. No runbook has this status.

A command in a runbook is for the maintainer to run. Each command that has not been run is marked (planned, not run). A command that also depends on a fact the repository does not confirm carries a line that starts with "Unsure:". Where the repository does not say, the runbook says it is not known.

## Before you use a runbook

- The `kubectl` commands assume that `kubectl` points at the session cluster. `session.sh bootstrap` writes the administrator kubeconfig outside the repository (`PP_PLAN_DIR`). The Entra ID kubeconfig is described in [infrastructure/README.md](../../infrastructure/README.md). Both are planned and have not run.
- The namespace of the service is `apps`, the Deployment is `sample-service`, and the Argo CD Applications are in the namespace `argocd`: `root`, `cluster-rules`, `sample-service` and `opentelemetry-collector`.
- The cluster exists only during a live session (ADR 0009). Between sessions there is nothing to run these commands against.
- Output from `kubectl` and `az` can hold identifiers and addresses. `session.sh` masks its own output, and these commands do not. Do not paste unmasked output into a pull request, an issue or a file in the repository.

## Template

Every runbook has these headings, in this order.

| Heading | Content |
|---|---|
| Trigger | What starts the runbook: the alert, the experiment or the symptom |
| Impact | What the failure does, from the files |
| First checks | A numbered list of commands. Each has one line on what it shows |
| Likely causes | The causes that the repository names, with where each is named |
| Fix | A numbered list of commands. Each has one line on what it does |
| Verify | How to tell that the failure is gone |
| Rollback | How to undo the fix |
| Source | The alert, the experiment number or the ADR |
| Status | `not exercised`, or `exercised in <session>` |

## Index

| Runbook | Trigger | Status |
|---|---|---|
| [availability-burn.md](availability-burn.md) | Alerts AvailabilityFastBurn (severity 1) and AvailabilitySlowBurn (severity 2) | not exercised |
| [latency-burn.md](latency-burn.md) | Alerts LatencyFastBurn (severity 1) and LatencySlowBurn (severity 2) | not exercised |
| [pod-not-ready.md](pod-not-ready.md) | A pod of the sample service is deleted or is not ready | not exercised |
| [node-drain.md](node-drain.md) | A node is drained and pods stay pending or move | not exercised |
| [bad-image-tag.md](bad-image-tag.md) | A bad image tag is deployed | not exercised |
| [argocd-drift.md](argocd-drift.md) | A resource is edited by hand | not exercised |
| [network-policy-blocks-service.md](network-policy-blocks-service.md) | Probes fail because a policy blocks the service | not exercised |
| [key-vault-mount-fails.md](key-vault-mount-fails.md) | Sample service pods stay in ContainerCreating because the secret mount fails | not exercised |
| [image-pull-refused.md](image-pull-refused.md) | The image cannot be pulled from `ghcr.io` | not exercised |
| [session-leftovers.md](session-leftovers.md) | `session.sh check` exits 1 | not exercised |

Session 2 experiment 3 (inject errors and latency) has no runbook of its own. It is how the two burn-rate runbooks are exercised.

## Changing a runbook

A runbook is changed in the pull request that changes the behaviour it describes. When a session exercises a runbook, the same pull request that records the session changes the status line of the runbook and this index.
