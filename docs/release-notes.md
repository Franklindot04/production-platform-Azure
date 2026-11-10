# Release notes

No release has been published. This page says how release notes are written and holds the notes of the first release, which is planned and not tagged.

## How release notes are written

Each release has four parts:

1. **Summary.** What the release contains, in a few sentences.
2. **Changes.** What was added or changed since the last release.
3. **Known limitations.** What was not tested and what is open.
4. **Rebuild steps.** How to create the platform again from the repository.

The changelog ([changelog.md](changelog.md)) lists what is on `main`. Release notes are written when a release is tagged.

## First release (planned, not tagged)

### Summary

The first release would hold the platform as it is on `main`: Terraform for the `dev` environment, an AKS session layer that is created and destroyed in a session, a sample service delivered through Argo CD, metrics and traces, SLOs with burn-rate alerts, runbooks and a postmortem. It has been run in two live sessions. No cluster is running now.

### Changes

See the Unreleased section of [changelog.md](changelog.md).

### Known limitations

From [Session 2 results](sessions/session-2-results.md), not tested:

- `slow-requests.kql` with real slow requests
- The latency alerts (LatencyFastBurn, LatencySlowBurn) and the latency-burn runbook
- Removal of a node instance
- The network policy block experiment
- The repeat step of the destroy after a failed destroy
- The range test from more than one other address
- A screenshot of the Argo CD UI
- A cost snapshot

Open issue: #98, a node drain does not complete on the two node cluster.

From the [runbook index](runbooks/README.md), the runbooks that have not been exercised: latency-burn, pod-not-ready, argocd-drift, network-policy-blocks-service, key-vault-mount-fails, image-pull-refused and session-leftovers.

Other limits are in [architecture.md](architecture.md): the 4 vCPU regional quota, the two node pool, and `staging` and `prod`, which are planned.

### Rebuild steps

The run sheet is in [session-2.md](sessions/session-2.md). The commands and the settings they need are in the [infrastructure README](https://github.com/Franklindot04/production-platform-Azure/blob/main/infrastructure/README.md).

1. Check that nothing remains: `./infrastructure/session.sh check` exits 0.
2. Set the authorized range in `TF_VAR_api_authorized_ip_ranges` and the admin group in `TF_VAR_cluster_admin_group_object_id`. Both are set at run time and are not stored.
3. Plan: `./infrastructure/session.sh up`. Read the plan.
4. Apply: `./infrastructure/session.sh up --apply`.
5. Bootstrap: `./infrastructure/session.sh bootstrap`.
6. Wait until the four Applications are Synced and Healthy and `/healthz` answers 200 on the ingress.
7. Tear down: `./infrastructure/session.sh down`, then `./infrastructure/session.sh down --yes`, then `./infrastructure/session.sh check`. The session ends when `check` exits 0.

In Session 2 the new cluster reached Healthy with no manual step after bootstrap, 772 seconds after the start.
