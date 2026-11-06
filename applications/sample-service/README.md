# sample-service

The workload that the platform's SLOs measure. A small Go service with health endpoints and a work endpoint whose latency and error rate can be changed at run time. See [ADR 0014](../../docs/adr/0014-sample-service.md).

## Endpoints

On the API port (default 8080):

| Path | Behaviour |
|---|---|
| `GET /healthz` | Liveness. Returns 200. |
| `GET /readyz` | Readiness. Returns 200, or 503 after the process gets a termination signal. |
| `GET /work` | Waits for the configured latency, then returns 200, or 500 with the configured error probability. |

On the admin port (default 8081). The Kubernetes Service does not expose it, and the ingress cannot reach it:

| Path | Behaviour |
|---|---|
| `GET /admin/config` | Returns the current latency and error rate. |
| `PUT /admin/config` | Sets `latency` (a duration such as `200ms`, 0 to 5s) and `error_rate` (0 to 1). Either field can be left out. Unknown fields are rejected. |

A setting made through the admin port applies to one pod and is lost when the pod restarts.

`/metrics` and traces are not part of the service yet.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `8080` | API port |
| `ADMIN_PORT` | `8081` | Admin port |
| `LATENCY` | `0s` | Starting latency of `/work` |
| `ERROR_RATE` | `0` | Starting error probability of `/work` |
| `SHUTDOWN_DELAY` | `0s` | Time between reporting not ready and closing the listeners |

## Run and test

```bash
cd applications/sample-service
go vet ./...
go test -race ./...
go run .
```

## Image

The Dockerfile builds a static binary into an image with nothing else in it. The container runs as user 65532.

```bash
docker build -t sample-service:local applications/sample-service
```

Images are published to `ghcr.io` by a workflow (ADR 0013). No workflow exists yet.
