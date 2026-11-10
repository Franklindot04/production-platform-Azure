# gitops

Argo CD Application definitions and the values per environment. Only `dev` exists.

| Path | Content |
|---|---|
| `dev/root-application.yaml` | The root Application. The bootstrap step of `infrastructure/session.sh` applies it once (ADR 0017). It creates the other three Applications. It was Synced and Healthy in Session 1. |
| `dev/apps/cluster-rules.yaml` | Syncs `kubernetes/` first (sync wave 0) |
| `dev/apps/sample-service.yaml` | Syncs the chart in `helm/sample-service` with the `dev` values (sync wave 1) |
| `dev/apps/opentelemetry-collector.yaml` | Installs the upstream `opentelemetry-collector` chart 0.178.2 in `observability` with the `dev` values (sync wave 1, ADR 0025). It was Synced and Healthy in Session 1 |
| `dev/values/sample-service.yaml` | The `dev` values: the image, the ingress, tracing, and the name of the Key Vault secret. The identity values of the secret mount are not here. `session.sh bootstrap identity` sets them on the Application at run time (ADR 0029) |
| `dev/values/opentelemetry-collector.yaml` | The Collector values: the contrib image, one traces pipeline to Azure Monitor, and the connection string read from the secret `appinsights-connection` |

All Applications use automated sync with prune and self-heal. The root Application ignores differences on `/spec/source/helm/parameters` of the Applications it creates and respects that setting when it syncs, so the parameters set at run time stay. Session 1 showed both: the parameters stayed, and self-heal reverted a manual change to the Ingress. The repository is public, so Argo CD needs no repository credential.

The image tag in `dev/values/sample-service.yaml` is a commit SHA. The workflow `image-tag-bump.yml` sets it through a pull request (ADR 0018) after an image is published. The pods can pull the image only if the package on `ghcr.io` is public.

The ingress class is the one of the AKS application routing add-on (ADR 0016). How the ingress is limited to the maintainer's address is not settled.

```bash
kubeconform -strict -summary -kubernetes-version 1.36.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  gitops/dev/root-application.yaml gitops/dev/apps
```
