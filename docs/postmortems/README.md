# Postmortems

A postmortem is a short written account of an incident: what happened, why, and what changes because of it. It follows the [incident process](../incident-process.md).

One postmortem has been written.

## When one is written

1. Every level 1 incident.
2. A level 2 or level 3 incident when a runbook did not work, or when the failure was new.

The levels are in the severity table of the incident process.

## Rules

- A postmortem is blameless. It describes what the system and the process did, not who is at fault.
- It uses the time since the start of the session, for example 0:35. It has no calendar date and no clock time.
- It holds no identifier, address or credential. Output is masked first.
- It is kept in this folder as `<n>-<short title>.md`, with `n` starting at 1. Use [template.md](template.md).
- The pull request that adds it also changes the Status line of the runbook it used and the runbook index.

## Index

| Title | Level | Runbook | Link |
|---|---|---|---|
| Planned error injection and the availability alerts | 1 | [availability-burn.md](../runbooks/availability-burn.md) | [1-error-injection-availability-alerts.md](1-error-injection-availability-alerts.md) |
