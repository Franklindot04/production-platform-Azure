# Contributing

This repository is maintained by one person. These rules keep the history readable and make each change easy to review.

By taking part, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Work tracking

Work is tracked in GitHub issues. Each epic is an issue with the `epic` label. Tasks are sub-issues of an epic and carry the `task` label. Every change starts from an issue. Some issues may also carry a Jira key (PP-number) in the description.

## Branches

Branch from an up-to-date `main`. Name branches `type/issue-number-short-name`.

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.

Examples:

- `docs/13-adr-template`
- `feat/21-terraform-state-backend`
- `fix/34-aks-node-pool-size`

Where one PR closes several issues, use the main issue number or a short name for the group, for example `chore/foundation-repo-setup`.

## Commits

- Imperative mood, lower case, no trailing period: `add pull request template (#11)`.
- One logical change per commit.
- Put the issue number at the end of the subject line.
- Add a body only when the reason for the change is not obvious.

## Pull requests

1. Open a pull request from your branch to `main`.
2. Fill in the template: linked issue, what changed, how it was tested, limitations.
3. Write `Closes #n` for each issue the PR completes.
4. Wait for review and for checks to pass, once checks exist.
5. Merge only after review. Delete the branch after merging.

Keep PRs small. If a PR needs more than one sentence to describe, consider splitting it.

## Definition of done

A task is done when it is verified, not when it is merged.

- The acceptance criteria in the issue are checked off, each one against something you observed.
- The change was run or tested, and the PR says how.
- Docs and the README match the new state.
- Anything left out is written down in the PR under limitations, or as a new issue.

## Numbering

Lists, phases and milestones start at 1. ADR numbers start at 0001.

## Decisions

Significant decisions are recorded in `docs/adr/`. See [ADR 0002](docs/adr/0002-record-decisions-as-adrs.md).
