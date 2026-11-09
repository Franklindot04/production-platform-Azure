# ADR 0020: Choose policy and scanning tools

- Status: proposed
- Date: 2026-11-06
- Issue: #28

## Context

Epic 6 needs checks that stop unsafe changes. The architecture document left the policy tool open. An admission policy engine in the cluster uses memory and CPU, and only about 2.5 vCPU and 9.8 GiB of requests are left after the system pods (ADR 0012). GitHub secret scanning and push protection are already on for this repository.

## Decision

- Checks run in CI, on pull requests (issue #44):
  - Trivy scans the Terraform and the Kubernetes manifests and chart for misconfiguration, and the image for vulnerabilities and secrets.
  - `kubeconform` checks the manifests against the Kubernetes schemas.
- A finding of severity HIGH or CRITICAL fails the run. An accepted finding is recorded in an ignore file with a reason.
- Actions and tool versions are pinned (full SHAs for actions) when the workflow is written.
- No admission policy engine is installed in the cluster. Namespaces carry Pod Security Admission labels instead (issue #30), which the cluster enforces without extra pods.

## Pinned versions

- Action: `aquasecurity/trivy-action` at SHA `57a97c7e7821a5776cebc9bb87c984fa69cba8f1` (v0.35.0).
- Trivy: v0.69.3, set as the `version` input on every Trivy step.
- Reason: the version tags of the action and Trivy v0.69.4 were replaced with malicious code in March 2026. This SHA and v0.69.3 are the versions that the vendor's advisory names as safe.
- The ignore-file format and the action inputs are checked by the first run of the workflow.

## Consequences

- Policy is enforced before merge. A manifest applied by hand with `kubectl` bypasses the scans, but Argo CD reverts drift from Git, and the Pod Security labels still apply at admission.
- The scans need network access to fetch their databases when they run.
- False positives are handled with the ignore file, and each entry needs a reason.

## Alternatives considered

- Checkov, kube-linter or other scanners. Not compared.
- Kyverno, OPA Gatekeeper or the Azure Policy add-on in the cluster. Their memory and CPU use is not measured, and the capacity is small.
