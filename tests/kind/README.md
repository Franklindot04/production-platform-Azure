# tests/kind

Checks that need no Azure: static checks on the files and live checks in a local kind cluster.

```bash
./tests/kind/check.sh            # static and live checks, creates and deletes the cluster
./tests/kind/check.sh --static   # static checks only
./tests/kind/check.sh --reuse --keep   # reuse and keep the cluster between runs
```

The workflow `app-checks.yml` runs this script on pull requests that change the service, the chart, the cluster rules or the GitOps files.

It needs `go`, `helm`, `kubeconform`, `kind`, `kubectl` and `docker`. `yamllint` is used if it is installed.

## Static checks

- `go vet`, `go test` and `gofmt` on the sample service.
- `helm lint` with the `dev` values, and a check that the chart fails to render without an image tag.
- `kubeconform` on the rendered chart, on `kubernetes/`, and on the Argo CD Applications. The Applications use the schemas of a public CRD catalog, so that check needs network access.

## Live checks

A cluster with one control plane and two workers is created, the image is built and loaded, and the cluster rules and the chart are installed. The script then checks:

- Both replicas are ready and run on different nodes.
- The Service exposes port 80 only.
- `/healthz`, `/readyz` and `/work` answer, the admin port changes the error rate, and the API port does not serve the admin path.
- Pod Security rejects a privileged pod in `apps`.
- The limit range gives default requests and rejects a container above its maximum, and the quota counts the pods.
- The bootstrap step of `infrastructure/session.sh` installs Argo CD, and Argo CD syncs the cluster rules from the main branch on GitHub. The credential command refuses a non-terminal and prints on a terminal. The step stops without an ingress range, and it sets the range on a stand-in for the add-on's resource. These checks need network access to GitHub and the Helm repository.
- A pod in the `default` namespace cannot reach the service, and a pod in `app-routing-system` can. These two lines are reported as information, as yes, no or unknown. If the cluster is unhealthy or does not enforce policies, the script says so and does not fail.

## Limits

- A kind cluster does not show the AKS load balancer, Azure CNI Overlay, Azure Network Policy Manager, or the ingress add-on.
- Creating three nodes can take several minutes on a Docker VM with 4 GB of memory. On that VM the create failed in some attempts, so the script tries it up to three times, and the scheduler and controller manager restarted on a cluster that had run for a while. A larger Docker VM was not tried.
- Images are loaded from a single-platform archive, because `kind load docker-image` fails with the containerd image store of recent Docker releases.
