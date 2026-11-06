# helm

Charts written in this repository.

| Chart | Content |
|---|---|
| [sample-service](sample-service/) | Deployment with two replicas spread over the nodes, probes, requests and limits, a restricted security context, a Service on port 80 (the admin port is not exposed), a disruption budget, a service account without a token, an optional Ingress, and an optional PodMonitor |

The image tag has no default. The chart fails to render without `image.tag`. The `dev` values are in `gitops/dev/values/sample-service.yaml`.

The PodMonitor (`metrics.scrape.enabled`, off by default) tells the managed Prometheus agent to scrape `/metrics` on the `admin` container port of each pod, every `metrics.scrape.interval` (default `30s`). It uses the resource type `azmonitoring.coreos.com/v1`, which the managed Prometheus add-on installs. Leave it off until that add-on is enabled on the cluster, or the render applies a resource the cluster does not know. The `dev` values do not enable it.

Requests and limits are initial values. They are not measured on a cluster yet.

```bash
helm lint helm/sample-service -f gitops/dev/values/sample-service.yaml
helm template sample-service helm/sample-service -n apps -f gitops/dev/values/sample-service.yaml
```
