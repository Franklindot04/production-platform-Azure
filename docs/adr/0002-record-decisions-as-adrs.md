# ADR 0002: Record decisions as ADRs

- Status: accepted
- Date: 2026-11-03
- Issue: #13

## Context

This project is built by one person over several weeks. Choices about tooling, structure and trade-offs are easy to forget. Without a record, the reason for a choice is lost and the same question gets argued again.

## Decision

We record each significant decision as an Architecture Decision Record (ADR) in `docs/adr/`.

- One file per decision, named `NNNN-short-title.md`.
- Numbers start at 0001 and increase by one. `0001-template.md` is the template.
- A record is short: context, decision, consequences, alternatives.
- Records are not edited after acceptance, except to change the status. A new decision that replaces an old one gets a new ADR, and the old one is marked superseded.
- A decision that changes infrastructure, tooling or structure is recorded in the same pull request that makes the change.

## Consequences

- Decisions can be found and read later.
- Each decision costs a few minutes of writing.
- Small choices do not need an ADR. If a choice is easy to reverse and affects one file, skip it.

## Alternatives considered

- Keep decisions in issue comments. They are hard to find and are not versioned with the code.
- Keep decisions in the README. It would grow without limit and mix current state with history.
