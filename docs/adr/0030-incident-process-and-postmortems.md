# ADR 0030: Set the incident process and write postmortems

- Status: proposed
- Date: 2026-11-09
- Issue: #47

## Context

The platform has one maintainer and no on-call rotation (`docs/architecture.md`). The cluster exists only during a live session (ADR 0009). The burn-rate alerts have severities 1 and 2 (ADR 0028, `alerts.tf`). The runbooks (issue #46) say that the response time for those severities is not known. No incident has happened and no process has been used.

## Decision

- Three incident levels. Level 1 and level 2 are the severities of the burn-rate alerts, so an alert and its incident have the same number. Level 3 covers what has no alert, such as resources left after a session or a failed session step. A leaked credential is level 1. Resources still billing are level 3.
- The response is stated as actions, such as "stop other work" and "finish the current step first". It has no times, because none has been measured. A number written now would be a guess and would read as a promise.
- One maintainer and no rota. The process is a list of steps for one person: detect, classify, stabilise with the runbook, recover and verify, record, follow up.
- A postmortem is written for every level 1 incident, and for a level 2 or 3 incident when a runbook did not work or the failure was new.
- Postmortems are blameless and are kept in `docs/postmortems/`, from one template.
- A postmortem has no calendar date or clock time. Its timeline uses the time since the start of the session.
- The process is in `docs/incident-process.md`. The template is `docs/postmortems/template.md`.

## Consequences

- The process is untested. No incident has used it, and it is a proposal.
- A first real incident should check:
  1. Whether the level was clear from the table, or whether two levels seemed to fit.
  2. Whether actions without times were enough, or whether the maintainer needed a time.
  3. Whether the criteria produced the right postmortems, or too many or too few.
  4. Whether the process page was easy to find and follow during a session.
  5. Whether the runbook for the level worked, and what it lacked.
- A time can be added to the table only after values have been measured, and that needs a new decision.
- Because alerts go to email and nobody is paged, an alert is seen only when the maintainer reads the mail. The burn-rate alerts need the service to run, so they cannot detect an incident outside a session.
- The levels apply to the failures the repository knows. A new kind of failure is classified by judgement and then added to the table.

## Alternatives considered

- A severity table with response times. No time has been measured, and the maintainer works in sessions. Not chosen now.
- Incident tracking with an issue template. It adds a place to keep in step with the postmortem for a project with one maintainer and no incident so far. Not chosen now. It can be added after a first incident shows what is missing.
- No written process. The runbooks say how to fix a failure but not how urgent it is or what to record, and the criteria for a postmortem would be decided during the incident.
