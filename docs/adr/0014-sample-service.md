# ADR 0014: Write the sample service in Go

- Status: proposed
- Date: 2026-11-06
- Issue: #39

## Context

The platform needs one workload for the SLOs to measure. It has to start fast, use little memory, answer health checks, and let load tests and failure experiments change its behaviour: how long a request takes and how often it fails. Capacity is tight: about 2.5 vCPU and 9.8 GiB of requests are left after the system pods (ADR 0012).

## Decision

- The service is written in Go. The maintainer chose the language. Other languages were not compared.
- It lives in `applications/sample-service/` and uses the standard library HTTP server.
- It is built into a small image with a static binary, and the container runs as a non-root user.
- Endpoints on the service port:
  - `GET /healthz` for liveness.
  - `GET /readyz` for readiness.
  - `GET /work` waits for the configured latency and fails with the configured probability.
  - `GET /metrics` in Prometheus format (issue #49).
- Latency and error rate are set at run time through `PUT /admin/config` on a separate admin port. The Service and the ingress do not expose the admin port. It is reached by port-forward or from inside the cluster.
- Starting values come from environment variables, and the values are validated: a latency cap of 5 seconds and an error rate from 0 to 1.
- Logs are written to standard output.

## Consequences

- Fault injection cannot be reached from the ingress.
- A setting made through the admin port applies to one pod, and it is lost when the pod restarts. A setting that must apply to every replica goes in the `gitops/` values and is rolled out by Argo CD, which takes longer.
- The service is built and tested by the workflows in Epic 4.
- The memory and CPU of the service are not measured yet.

## Alternatives considered

- Another language. Not compared.
- Setting latency and error rate with query parameters on `/work`. Anyone who can reach the ingress could then inject faults.
- A ready-made demo application. It would not give control over latency and errors.
