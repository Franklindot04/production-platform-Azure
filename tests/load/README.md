# Load tests

A k6 script that sends `GET /work` to the sample service at a set request rate. The script is `sample-service.js`. It uses only the k6 built-in modules. `/healthz` and `/readyz` are probes and are not load targets.

Each request is tagged with the route `/work` and checked for status 200.

## Scenarios

`SCENARIO` selects the load. It is required. An unknown name stops the script with a list of the valid names.

| Scenario | Load |
|---|---|
| `smoke` | 5 requests per second for 10 seconds |
| `baseline` | `RATE` requests per second (default 20) for `DURATION` (default 10m) |
| `ramp` | Steps of 10, 20, 40, 80 and 160 requests per second. Each step is reached over 30 seconds and held for `STEP_DURATION` (default 3m) |

Set `STEPS` (comma separated rates) and `STEP_DURATION` to change the ramp. `PRE_ALLOCATED_VUS` (default 50) and `MAX_VUS` (default 200) apply to all scenarios. The variables are described at the top of the script.

`BASE_URL` is required and has no default. A trailing slash is removed.

## Install

Install k6 on the machine that runs the test. On macOS: `brew install k6`. For other systems, see the k6 documentation.

## Run against a local service

```bash
cd applications/sample-service && go run .
```

In a second terminal, from the repository root:

```bash
SCENARIO=smoke BASE_URL=http://localhost:8080 k6 run tests/load/sample-service.js
```

## Run against the cluster

The service is reached through the ingress on the public address of the load balancer, over plain HTTP. Access is limited to the maintainer's address range (ADR 0016). There is no domain, and the address is not stored in the repository.

```bash
SCENARIO=baseline BASE_URL=http://<ingress address> k6 run tests/load/sample-service.js
SCENARIO=ramp BASE_URL=http://<ingress address> k6 run tests/load/sample-service.js
```

To save the results:

```bash
SCENARIO=baseline BASE_URL=http://<ingress address> k6 run --summary-export=<file> tests/load/sample-service.js
```

The saved output can contain the address. Mask it before the file is committed.

## Changing the service while a test runs

The admin port (8081) is not exposed by the Service or the ingress. To change the latency or the error rate, forward the port to a pod and call `PUT /admin/config`. The namespace is `apps` and the Deployment is `sample-service`.

These commands are planned and have not been run:

```bash
kubectl port-forward -n apps deploy/sample-service 8081:8081
curl -X PUT http://localhost:8081/admin/config -d '{"latency":"800ms","error_rate":0.2}'
```

A setting applies to one pod only and is lost when the pod restarts. See `applications/sample-service/README.md`. The Service sends requests to all pods, so a change on one pod changes only part of the traffic.

## Thresholds

The script sets two thresholds that mirror the SLOs in `docs/slos.md`:

- `http_req_failed` rate below 0.01. This matches the availability target of 99%. k6 counts any status of 400 or more as failed.
- `http_req_duration` p(95) below 500 ms. This matches the latency target of 95% within 0.5 seconds.

k6 reports whether each threshold held. The thresholds do not stop the run.

## Status

The `smoke` scenario has been run against the service on a local machine. The `baseline` and `ramp` scenarios have not been run, and nothing has been run against a cluster.

Not built:

- A CI job for the script (planned if it is wanted).
- Results. They come from Session 2.
