# helm

Charts written in this repository.

| Chart | Content |
|---|---|
| [sample-service](sample-service/) | Deployment with two replicas spread over the nodes, probes, requests and limits, a restricted security context, a Service on port 80 (the admin port is not exposed), a disruption budget, a service account without a token, and an optional Ingress |

The image tag has no default. The chart fails to render without `image.tag`. The `dev` values are in `gitops/dev/values/sample-service.yaml`.

Requests and limits are initial values. They are not measured on a cluster yet.

```bash
helm lint helm/sample-service -f gitops/dev/values/sample-service.yaml
helm template sample-service helm/sample-service -n apps -f gitops/dev/values/sample-service.yaml
```
