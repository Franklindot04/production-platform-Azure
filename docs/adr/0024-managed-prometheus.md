# ADR 0024: Enable managed Prometheus on the cluster

- Status: proposed
- Date: 2026-11-06
- Issue: #38

## Context

ADR 0008 sends Prometheus metrics to an Azure Monitor workspace in the persistent layer. The workspace is defined in the persistent root (ADR 0022). The sample service serves `/metrics` on its admin port, and the chart has a PodMonitor that is off by default (ADR 0023). The cluster has no metrics add-on yet. Capacity for workloads is small (ADR 0012).

## Decision

- Managed Prometheus is enabled with an empty `monitor_metrics` block on the cluster in the session root.
- The data collection endpoint, the data collection rule and the rule association are in the session root. They are destroyed with the cluster. Their shapes follow the Terraform template that Microsoft publishes for the add-on.
- The Azure Monitor workspace stays in the persistent layer. The session root looks it up by name, so metric history outlives the cluster.
- The PodMonitor of the sample service was off in the `dev` values until Session 1 showed that the add-on installed its custom resource definition. It is on in the `dev` values.

## Consequences

- Metric history survives teardown, because the workspace is not part of the session.
- The add-on adds pods in `kube-system`. They fit in the capacity that is left after the system pods, with the other tools (Session 1, `docs/sessions/session-1-results.md`).
- The add-on needs no extra role assignment for the cluster. This is taken from Microsoft's template and is not checked on AKS.
- The association name follows the template. Not checked on AKS.
- The session plan fails if the persistent workspace does not exist, because it is read with a data source.
- The saved plans in `docs/plans` do not include these resources.
- Nothing in this change is applied.

## Alternatives considered

- Put the endpoint and the rule in the persistent root. That needs a persistent apply, and it gives the plan identity more to read.
- Enable the add-on with the Azure CLI. That is a manual step outside Terraform.
- Self-hosted Prometheus in the cluster. Rejected in ADR 0008: history is lost on teardown.
