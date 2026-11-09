# Incident process

Status: proposed (ADR 0030). The process has not been used. No incident has happened, and nothing here says how well it works.

## Setting

- There is one maintainer and no on-call rotation (`docs/architecture.md`, non-goals). Alerts go to email, and nobody is paged.
- The cluster exists only during a live session (ADR 0009). Most incidents happen during a session, and the maintainer is already at the keyboard.
- Between sessions only the persistent layer, the state storage and the repository exist. An incident outside a session is limited to those: a leaked credential, resources still billing, a problem with the Azure account, or a problem with the state. The cluster runbooks do not apply then.

## Severity

Level 1 and level 2 are the severities of the burn-rate alerts in `infrastructure/environments/dev/persistent/alerts.tf` (ADR 0028). The alert severity and the incident level are the same number. Level 3 covers what has no alert.

The response is given as actions. No time is given, because no response time has been measured.

| Level | Meaning | Examples from this repository | What the maintainer does | Postmortem |
|---|---|---|---|---|
| 1 | The error budget burns fast, or an exposure cannot be undone | AvailabilityFastBurn, LatencyFastBurn. A leaked credential: the repository is public, so a pushed value counts as exposed (`docs/security.md`, rule 8) | Stop other work. Use the runbook, or for a credential rotate it first | Always |
| 2 | The error budget burns slowly | AvailabilitySlowBurn, LatencySlowBurn | Finish the current step first. Then use the runbook | When a runbook did not work or the failure was new |
| 3 | No alert exists for it | Resources left after a session (`session.sh check` exits 1). A failed session step. A failed gate in a session run sheet. A failure found by a check | Note it. Fix it before the session ends, or before the next one starts. Use the runbook if there is one | When a runbook did not work or the failure was new |

Why a leaked credential is level 1: it cannot be undone once pushed, and the repository is public. Why resources still billing are level 3: no user is affected, the fix is one script (`session.sh down`), and the control is the check at the end of each session (ADR 0009). They cost money while they remain, so do not leave them.

## Steps

1. **Detect.**
   - The alert email from the action group `pp-dev-alerts`. The address is set at run time.
   - A step of `infrastructure/session.sh` that fails, and `session.sh check` at the end of a session.
   - The k6 summary (`tests/load/README.md`) and the query files in `monitoring/prometheus/`, for example `request-rate.promql` and `error-ratio.promql`.
   - A service that receives no requests produces no data and no alert (`docs/slos.md`). During a session, look at `request-rate.promql` and do not wait for an email.
2. **Classify.** Choose the level from the table. If unsure between two levels, take the lower number.
3. **Stabilise.** Find the runbook in the [runbook index](runbooks/README.md) and follow its First checks and Fix. If no runbook fits, that is a gap: note it. The options are a revert in Git, or ending the session with `./infrastructure/session.sh down`.
4. **Recover and verify.** Use the Verify section of the runbook. The SLI queries `monitoring/prometheus/availability-sli.promql` and `latency-sli.promql` show the service back within its targets. At the end of every session, `./infrastructure/session.sh check` must exit 0.
5. **Record.** While it happens, note what you did against the time since the start of the session, for example 0:35. Save the output with its masking (`session.sh` masks its own output). Do not save identifiers or addresses. Write a postmortem when the table says so, using [the template](postmortems/template.md).
6. **Follow up.** Open an issue for each action. Fix the runbook that did not work, in the pull request that changes the behaviour. When a runbook was used, change its Status line and the index in `docs/runbooks/README.md`.

## A leaked secret

Follow `docs/security.md` (rule 8) and `SECURITY.md`. They are not repeated here. It is level 1, and it needs a postmortem.

## Not built

- An issue template for incidents. Not chosen (ADR 0030).
- An alert for missing data (`docs/slos.md`).
- Budget alerts (`docs/architecture.md`).
