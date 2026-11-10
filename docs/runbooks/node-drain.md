# Node drain

## Trigger

A node of the session cluster is drained, and sample service pods stay pending or move to the other node. Session 2 experiment 2 drains one node on purpose.

## Impact

The cluster has two nodes and the regional quota is 4 vCPU, so there is no spare capacity for a third node (ADR 0003, ADR 0012). The hypothesis of experiment 2 is that the pods move to the other node, or stay pending if it has no room. In Session 2 seven pods stayed Pending with insufficient CPU on the remaining node: one sample service replica, three Argo CD pods, the second metrics-server pod, retina-agent and the collector. The drain did not complete (#98). Pods of other tools on the node are evicted too.

The chart has a PodDisruptionBudget with `minAvailable: 1` and 2 replicas. The pods are spread over nodes with `whenUnsatisfiable: ScheduleAnyway`, so both can land on one node.

## First checks

1. `kubectl get nodes` (planned, not run). It shows the nodes and which one is `SchedulingDisabled`.
2. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). It shows the node of each pod and any pod in `Pending`.
3. `kubectl describe pod -n apps <pod name>` (planned, not run). For a pending pod, the events show why it was not scheduled, for example not enough CPU or memory.
4. `kubectl describe nodes` (planned, not run). It shows the requests already placed on each node.
5. `kubectl get pods -A --field-selector=status.phase=Pending` (planned, not run). It shows every pending pod, including those of Argo CD and the Collector.

## Likely causes

- The other node has no room for the pods that were evicted. The events of the pending pod say so.
- An eviction is held back by the PodDisruptionBudget. With 2 replicas and `minAvailable: 1`, the drain evicts one pod and waits before it evicts the other. This follows from the budget in the chart and is not observed for the sample service. In Session 2 the disruption budget of metrics-server blocked its eviction.
- The quota of the namespace `apps` is used up. See [pod-not-ready.md](pod-not-ready.md).

Other causes are not known from the repository.

## Fix

1. Start the drain for the experiment: `kubectl drain <node name> --ignore-daemonsets` (planned, not run). It evicts the pods of the node and marks it unschedulable. The drain does not complete on the two node cluster today (#98).
2. When the experiment ends, make the node schedulable again: `kubectl uncordon <node name>` (planned, not run). Pending pods can then be placed on it.
3. If a pod is still pending after the uncordon, delete it: `kubectl delete pod -n apps <pod name>` (planned, not run). The Deployment creates a new one.
4. Do not add a node. The quota of 4 vCPU is in use (`docs/sessions/session-2.md`).

The flags `--ignore-daemonsets` and `--delete-emptydir-data` were accepted in Session 2.

## Verify

1. `kubectl get nodes` (planned, not run). Both nodes show `Ready` without `SchedulingDisabled`.
2. `kubectl get pods -n apps -l app.kubernetes.io/name=sample-service -o wide` (planned, not run). Both pods are ready.
3. `kubectl get pods -A --field-selector=status.phase=Pending` (planned, not run). No pods are listed.

## Rollback

`kubectl uncordon <node name>` (planned, not run). Pods that moved do not move back by themselves. Delete one if you want it to be placed again.

## Source

Session 2 experiment 2, ADR 0003, ADR 0012, `helm/sample-service/templates/pdb.yaml`.

## Status

exercised in Session 2. The drain did not complete (#98)
