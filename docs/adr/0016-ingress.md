# ADR 0016: Choose the ingress

- Status: proposed
- Date: 2026-11-06
- Issue: #39

## Context

The sample service has to be reachable from outside the cluster so that load tests and the SLOs measure real requests. There is no domain and no certificate. The choice was the lighter of the AKS application routing add-on or one self-installed controller. Capacity is tight: about 2.5 vCPU and 9.8 GiB of requests are left after the system pods (ADR 0012).

Facts read from the documentation:

- The application routing add-on runs a managed NGINX controller. It is enabled without a DNS zone. DNS is optional.
- By default it creates a controller named `default` with a public Azure load balancer. The `NginxIngressController` resource scales it with `minReplicas` (default 2) and `maxReplicas` (default 100).
- The CPU and memory requests of the controller pods are not stated.
- Microsoft provides critical security patches for the NGINX add-on through November 2026, and the documentation says to migrate before then.
- The Kubernetes community project ingress-nginx stopped maintenance in March 2026: no more releases, bug fixes or security fixes.
- The replacement that AKS documents is the application routing Gateway API implementation. It runs an Istio control plane (`istiod`, two replicas by default, with an autoscaler from 2 to 5 replicas), and each Gateway runs at least two pods. The page read does not state whether it is generally available. Its Terraform example uses the `azapi` provider.
- The pages read do not say how to limit the source addresses of the load balancer.

## Decision

- Use the application routing add-on with its managed NGINX controller. It is the lighter option. Enable it in the session Terraform with the `web_app_routing` block, no DNS zone and `default_nginx_controller = "External"`.
- Serve plain HTTP on the public address of the load balancer. There is no domain and no certificate.
- The bootstrap step (ADR 0017) sets `minReplicas` to 1 and `maxReplicas` to 2 in the `scaling` field of the default `NginxIngressController` resource. If AKS refuses it, the step goes on with a warning. This is not checked on AKS.
- Limit the source addresses to the maintainer's range, set at run time. The bootstrap step puts the range in the `loadBalancerAnnotations` field of the default `NginxIngressController` resource, as the annotation `service.beta.kubernetes.io/azure-allowed-ip-ranges`. The step stops if no range is given or if the range is open to everyone. The documentation pages read do not state that the add-on passes the annotation to the Service, or that the load balancer enforces it. Session 1 checks both.
- Argo CD has no ingress (ADR 0017).

This is a short-lived choice. Support for the add-on ends in November 2026. The exposure is limited to one address, and the cluster exists only during a session, so the project accepts the risk for its planned life. Anything that lasts longer needs a new decision.

## Consequences

- The controller's pods use part of the capacity budget. Their requests are measured in Session 1.
- A second public IP address is used. The regional quota is 3, and the cluster's outbound address uses one.
- The Gateway API implementation is the documented replacement. It is heavier, because of the Istio control plane, and it needs a second Terraform provider.
- The community ingress-nginx controller is not installed, because it no longer gets security fixes.

## Open questions

- Does the annotation limit the load balancer to the range?
- Can the default controller be scaled to one replica?
- Which ingress replaces the add-on once its support ends?

## Alternatives considered

- The application routing Gateway API implementation. Heavier, and its support status is not stated in the page read.
- The community ingress-nginx controller. Maintenance ended in March 2026.
- Application Gateway for Containers. A paid Azure service. Not evaluated.
- No ingress, and port-forward only. Load tests through a port-forward do not measure the path that real requests take.
