# Session leftovers

## Trigger

`./infrastructure/session.sh check` exits 1 at the end of a session, or before the start of one.

## Impact

The session layer bills until it is destroyed (ADR 0009). A cluster that remains also keeps vCPU quota in use, and the regional quota is 4. The next cluster cannot be created while it remains (`docs/architecture.md`, risk table).

## First checks

1. `./infrastructure/session.sh check` (planned, not run). It lists every resource group with its resource counts, then prints one line per category, `none` or `REMAINS`. Exit 1 means something remains. Exit 0 means nothing remains. Exit 2 means an error or wrong use, for example the Azure CLI is not signed in. The output is masked and shows names and counts, not IDs.
2. Read the `== result` lines. `check` reports:
   - the session resource group `pp-dev-session-rg` or the node resource group `pp-dev-aks-nodes-rg`,
   - a cluster, virtual machine or scale set,
   - a public IP address, a load balancer or a managed disk,
   - a resource group that is not `pp-shared-state-rg`, `pp-dev-persistent-rg` or `NetworkWatcherRG`.
3. `./infrastructure/session.sh down` (planned, not run). It shows the destroy plan and destroys nothing. It shows what Terraform would still remove.

## Likely causes

- `down --yes` was not run, or it stopped with an error before it finished.
- The destroy failed part way. Terraform keeps what remains in the state.
- A state lock error ("Error acquiring the state lock") stops the command. The cause is not confirmed (`infrastructure/README.md`).
- A resource exists in Azure that is not in the Terraform state. The repository has no procedure for this case. It is not known what would create one.

Other causes are not known from the repository.

## Fix

1. `./infrastructure/session.sh down` (planned, not run). Read the plan. It shows what will be destroyed.
2. `./infrastructure/session.sh down --yes` (planned, not run). It destroys the session root. `down` needs no authorized range and no admin group value.
3. If it stops with a state lock error, run the command again. Whether that clears the error is not known.
4. `./infrastructure/session.sh check` (planned, not run). Repeat until it exits 0.
5. If something remains that Terraform does not know, the repository gives no way to remove it. Look at the names in the `check` output, decide by hand, and run `check` again. Do not remove `pp-shared-state-rg`, `pp-dev-persistent-rg` or `NetworkWatcherRG`: `check` does not count them, and the first two hold state and persistent resources.

## Verify

1. `./infrastructure/session.sh check` (planned, not run). It exits 0, and the result lines show `none`. The note about `pp-dev-persistent-rg` is expected.

## Rollback

A destroy cannot be undone. The session layer is created again with `./infrastructure/session.sh up` and `up --apply` (ADR 0009).

## Source

`infrastructure/README.md` (what `check` lists), `infrastructure/session.sh`, ADR 0009, Session 1 and Session 2 teardown steps.

## Status

not exercised
