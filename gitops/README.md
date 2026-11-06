# gitops

Argo CD Application definitions and the values per environment. Only `dev` exists.

| Path | Content |
|---|---|
| `dev/root-application.yaml` | The root Application. The bootstrap step of `infrastructure/session.sh` applies it once (ADR 0017). It is planned and does not exist yet. |
| `dev/apps/cluster-rules.yaml` | Syncs `kubernetes/` first (sync wave 0) |
| `dev/apps/sample-service.yaml` | Syncs the chart in `helm/sample-service` with the `dev` values (sync wave 1) |
| `dev/values/sample-service.yaml` | The `dev` values: the image and the ingress |

All Applications use automated sync with prune and self-heal. The repository is public, so Argo CD needs no repository credential.

The image tag in `dev/values/sample-service.yaml` is a commit SHA. The workflow `image-tag-bump.yml` sets it through a pull request (ADR 0018) after an image is published. The pods can pull the image only if the package on `ghcr.io` is public.

The ingress class is the one of the AKS application routing add-on (ADR 0016). How the ingress is limited to the maintainer's address is not settled.

```bash
kubeconform -strict -summary -kubernetes-version 1.36.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  gitops/dev/root-application.yaml gitops/dev/apps
```
