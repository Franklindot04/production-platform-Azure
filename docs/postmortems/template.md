# Postmortem: <short title>

Level: <1, 2 or 3>
Session: <name of the session record, or "outside a session">

This postmortem is blameless. Write what happened and what the process did, not who is at fault. Use the time since the start of the session, never a calendar date or a clock time. Mask identifiers and addresses.

## Summary

Write two or three sentences: what failed, for how long in session time, and how it ended.

## Impact

Write what the failure did to the service, the budget or the session, with numbers from the queries where you have them.

## Detection

Write how the failure was found: the alert, a command, a check or a person. Say how long after it started, in session time, if known.

## Timeline

Write one line per event, each with the time since the start of the session.

| Time | Event |
|---|---|
| 0:00 | <event> |

## Cause

Write the cause that the evidence shows. If it is not known, say so and name what is missing.

## What went well

Write what limited the damage or sped up the recovery.

## What went wrong

Write what made the failure worse, slower to find or slower to fix.

## Runbook

Write which runbook was used, whether it worked, and what did not match. Say which line of its Status changes, for example from `not exercised` to `exercised in <session>`. If no runbook fitted, say that.

## Actions

Write what changes because of this incident, as a numbered list. Each item links to an issue.

1. <action> (<issue link>)
