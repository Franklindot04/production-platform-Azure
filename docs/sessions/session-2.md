# Live session 2: load, failure and rebuild

Status: planned. Not run. Issue #50. Commands marked (planned) do not exist yet.

Goal: time a full rebuild from zero, measure the sample service under load, run failure experiments, and destroy everything.

Time box: about 2 hours. Teardown starts at 1:45 whatever is unfinished. An experiment marked optional is skipped when time is short.

Rules are the same as in [Session 1](session-1.md): approved plans, masked output, no stored credentials.

## Before the session

1. The fixes found in Session 1 are merged.
2. Every manual step from Session 1 has been replaced by code.
3. The load test scripts and the experiment list are in the repository and were run against `kind` where `kind` can show them.
4. The alert action group and the budget exist.

## Run sheet

| Time | Step | Command or action | Record |
|---|---|---|---|
| 0:00 | Preflight | vCPU use is 0 of 4, `./infrastructure/session.sh check` exits 0, the authorized range is set | Pass or fail |
| 0:05 | Timed rebuild | `./infrastructure/session.sh up --apply` after the plan is approved, then `bootstrap` (planned), with no other command | Time for each step and the time to a healthy service. This is the recovery time |
| 0:25 | Baseline | 10 minutes of steady load with k6 from the maintainer's machine | Request rate, error rate, latency percentiles, the SLIs |
| 0:40 | Ramp | Raise the load in steps until latency or errors rise | The load at which they rise |
| 1:00 | Experiments | The list below, one at a time. State the hypothesis first | Hypothesis, result, time to recover |
| 1:35 | Optional | Remove one node instance and watch AKS repair it. Skipped if time is short, because all 4 vCPU are in use and a retry can fail | Result |
| 1:45 | Wrap up | Cost snapshot, saved output and masked screenshots | Files saved |
| 1:50 | Teardown | `./infrastructure/session.sh down` then `down --yes`, then `./infrastructure/session.sh check` | Output of `check`. Exit 0 is the end |

## Experiments

1. Delete a pod of the sample service. Hypothesis: traffic continues, and a new pod is ready within the probe time.
2. Drain one node. Hypothesis: the pods move to the other node, or stay pending if it has no room. Record which.
3. Inject errors and latency with the service settings. Hypothesis: the burn-rate alert fires and the email arrives.
4. Deploy a bad image tag with a pull request, then revert it with Git. Hypothesis: Argo CD rolls back and the service recovers.
5. Edit a resource by hand with `kubectl`. Hypothesis: Argo CD reverts it.
6. Optional: apply a network policy that blocks the service. Hypothesis: the probes fail and the alert fires.

Each experiment feeds a runbook (#46). A runbook that no experiment exercised says `not exercised`.

## What is recorded

1. The rebuild time and each step's time.
2. The SLIs at baseline and at each load step.
3. The result of each experiment against its hypothesis.
4. The cost snapshot, as an amount per hour of cluster time.
5. Anything done by hand.

## After the session

1. `session.sh check` exits 0.
2. The results go into a pull request, with the first postmortem (#47).
3. The issue #50 criteria are ticked only for what was run.
