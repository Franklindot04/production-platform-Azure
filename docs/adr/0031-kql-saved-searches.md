# ADR 0031: Deploy the KQL queries as saved searches

- Status: proposed
- Date: 2026-11-11
- Issue: #40

## Context

ADR 0027 keeps queries as files that are run by hand, and lists saved searches as planned. The Log Analytics workspace `pp-dev-law` supports saved searches. The Azure Monitor workspace `pp-dev-amw` has no saved-query resource for PromQL. This ADR changes only the "run by hand" part of ADR 0027, and only for the three KQL files.

## Decision

- The three KQL files in `monitoring/logs` are deployed as saved searches on `pp-dev-law` by the persistent layer. The resources are defined in `infrastructure/environments/dev/persistent/saved-searches.tf`.
- Terraform reads the `.kql` files, so the files stay the single source of the query text. The comment header of each file stays in the saved query.
- The six PromQL files stay as files that are run by hand. ADR 0027 stays in force for them.
- Each saved search has the category "Sample service". The display names are "Failed requests", "Slow requests" and "Trace by operation".

What stays from ADR 0027: queries as files under `monitoring/`, review in pull requests, no Grafana, and the PromQL files run by hand.

## Consequences

- A change to a KQL file reaches Azure at the next persistent-layer apply.
- A saved search that is edited in the portal is overwritten by the next apply.
- The three saved searches are applied and exist on `pp-dev-law`.
- `trace-by-operation` keeps its placeholder operation id.
- Running the other queries is not part of this decision.

## Alternatives considered

- Keeping the KQL files as files that are run by hand (ADR 0027). Not chosen for the KQL files.
- An Azure workbook. Not evaluated.
