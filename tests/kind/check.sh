#!/usr/bin/env bash
# Checks the sample service, the chart, the cluster rules and the GitOps files
# without Azure. Static checks run on the files. Live checks run in a local
# kind cluster that is created and deleted by this script.
# Usage: check.sh [--static] [--keep] [--reuse] [--bootstrap]
#   --static     Run the static checks only. No cluster is created.
#   --bootstrap  Also run the bootstrap step of infrastructure/session.sh and check it.
#                It installs Argo CD, which needs more CPU than the other checks, and it
#                needs network access to GitHub and the Helm repository.
#   --keep       Keep the kind cluster after the checks.
#   --reuse      Use the kind cluster if it exists, instead of creating a new one.
#                Creating three nodes can take several minutes on a small Docker VM.
# Exit code: 0 if every required check passed, 1 otherwise.
# A kind cluster does not show the AKS load balancer, Azure CNI Overlay or
# whether network policy is enforced on AKS. Lines marked info are not checks.
set -euo pipefail

STATIC_ONLY=0
KEEP=0
REUSE=0
BOOTSTRAP=0
for arg in "$@"; do
  case "$arg" in
    --static) STATIC_ONLY=1 ;;
    --keep) KEEP=1 ;;
    --reuse) REUSE=1 ;;
    --bootstrap) BOOTSTRAP=1 ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER="pp-check"
CTX="kind-${CLUSTER}"
K8S_SCHEMA="1.36.0"
CRD_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
FAILED=0
PIDS=()
CLUSTER_UP=0

pass() { echo "pass: $*"; }
info() { echo "info: $*"; }
fail() {
  echo "fail: $*"
  FAILED=1
}

# expect "description" actual wanted   Compares two values and reports the result.
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got: ${2:-none}, want: $3)"; fi
}

# check "description" command...   Runs the command and reports the result.
check() {
  local what="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi
}

k() { kubectl --context "$CTX" "$@"; }

# retry times command...   Runs the command until it succeeds or the tries are used.
retry() {
  local tries="$1" i
  shift
  for i in $(seq 1 "$tries"); do
    if "$@"; then return 0; fi
    [ "$i" -lt "$tries" ] && sleep 10
  done
  return 1
}

# wait_cluster   Waits until the nodes and DNS are ready, for up to 15 minutes.
# A new cluster on a small Docker VM can refuse or time out on requests for
# several minutes after it is created.
wait_cluster() {
  local i
  for i in $(seq 1 90); do
    if k wait --for=condition=Ready node --all --timeout=10s >/dev/null 2>&1 &&
      k -n kube-system rollout status deployment/coredns --timeout=10s >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done
  return 1
}

# probe_http namespace name url   Runs a short-lived pod that fetches the URL.
# Prints yes if the fetch worked, no if it failed, and unknown if the pod did
# not finish, for example when the cluster is unhealthy.
probe_http() {
  local ns="$1" name="$2" url="$3" phase="" i
  k -n "$ns" delete pod "$name" --ignore-not-found >/dev/null 2>&1 || true
  if ! k -n "$ns" run "$name" --image=busybox:1.36.1 --image-pull-policy=Never --restart=Never -- \
    wget -q -T 5 -O /dev/null "$url" >/dev/null 2>&1; then
    echo unknown
    return
  fi
  for _ in $(seq 1 45); do
    phase="$(k -n "$ns" get pod "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "$phase" in
      Succeeded)
        echo yes
        k -n "$ns" delete pod "$name" --ignore-not-found >/dev/null 2>&1 || true
        return
        ;;
      Failed)
        echo no
        k -n "$ns" delete pod "$name" --ignore-not-found >/dev/null 2>&1 || true
        return
        ;;
    esac
    sleep 2
  done
  k -n "$ns" delete pod "$name" --ignore-not-found >/dev/null 2>&1 || true
  echo unknown
}

need() {
  command -v "$1" >/dev/null || {
    echo "missing tool: $1" >&2
    exit 2
  }
}

cleanup() {
  local pid
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null || true; done
  if [ "$STATIC_ONLY" = "0" ] && [ "$KEEP" = "0" ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Helpers for the Key Vault mount checks. The values are plain words, not real IDs.
FAKE_VAULT=(--set vaultSecret.enabled=true --set vaultSecret.clientId=fake-client
  --set vaultSecret.tenantId=fake-tenant --set vaultSecret.vaultName=fake-vault
  --set vaultSecret.objectName=fake-object)

# render_chart [helm args...]   Renders the chart with the dev values.
render_chart() {
  helm template sample-service "$REPO/helm/sample-service" -n apps -f "$REPO/gitops/dev/values/sample-service.yaml" "$@"
}

# vault_mount_needs_client_id   Succeeds if the render fails and names vaultSecret.clientId.
vault_mount_needs_client_id() {
  local out
  if out="$(render_chart --set vaultSecret.enabled=true --set vaultSecret.tenantId=fake-tenant \
    --set vaultSecret.vaultName=fake-vault --set vaultSecret.objectName=fake-object 2>&1)"; then
    return 1
  fi
  case "$out" in
    *vaultSecret.clientId*) return 0 ;;
    *) return 1 ;;
  esac
}

# vault_mount_renders   Succeeds if the render has the annotation, the class, the label and the mount.
vault_mount_renders() {
  local out want
  out="$(render_chart "${FAKE_VAULT[@]}")" || return 1
  for want in 'azure.workload.identity/client-id: "fake-client"' 'kind: SecretProviderClass' \
    'azure.workload.identity/use: "true"' 'driver: secrets-store.csi.k8s.io' 'mountPath: "/mnt/secrets"'; do
    if ! printf '%s\n' "$out" | grep -qF -- "$want"; then return 1; fi
  done
}

# vault_mount_absent_by_default   Succeeds if the default render has none of the mount.
vault_mount_absent_by_default() {
  local out unwanted
  out="$(render_chart)" || return 1
  for unwanted in 'azure.workload.identity' 'SecretProviderClass' 'secrets-store.csi'; do
    if printf '%s\n' "$out" | grep -qF -- "$unwanted"; then return 1; fi
  done
}

# vault_mount_valid   Validates the render with the CRD catalog. kubeconform fails if a schema is missing.
vault_mount_valid() {
  render_chart "${FAKE_VAULT[@]}" | kubeconform -strict -summary -kubernetes-version "$K8S_SCHEMA" \
    -schema-location default -schema-location "$CRD_CATALOG"
}

static_checks() {
  echo "== static checks"
  need go
  need helm
  need kubeconform

  check "go vet" bash -c "cd '$REPO/applications/sample-service' && go vet ./..."
  check "go test" bash -c "cd '$REPO/applications/sample-service' && go test -count=1 ./..."
  check "gofmt" bash -c "test -z \"\$(gofmt -l '$REPO/applications/sample-service')\""

  check "helm lint with the dev values" helm lint "$REPO/helm/sample-service" -f "$REPO/gitops/dev/values/sample-service.yaml"
  check "chart fails to render without an image tag" bash -c "! helm template x '$REPO/helm/sample-service' >/dev/null 2>&1"
  # The PodMonitor belongs to the managed Prometheus add-on and has no public schema, so
  # the validation skips that kind. The next check makes sure it is still rendered.
  check "chart renders valid resources with the dev values" bash -c "helm template sample-service '$REPO/helm/sample-service' -n apps -f '$REPO/gitops/dev/values/sample-service.yaml' | kubeconform -strict -summary -skip PodMonitor -kubernetes-version $K8S_SCHEMA"
  check "chart renders a PodMonitor with the dev values" bash -c "helm template sample-service '$REPO/helm/sample-service' -n apps -f '$REPO/gitops/dev/values/sample-service.yaml' | grep -q '^kind: PodMonitor'"
  check "chart fails to render with the Key Vault mount on and no client ID" vault_mount_needs_client_id
  check "chart renders the Key Vault mount when it is on" vault_mount_renders
  check "chart renders no Key Vault mount by default" vault_mount_absent_by_default
  check "chart with the Key Vault mount on is valid, with the CRD catalog" vault_mount_valid
  check "cluster rules are valid resources" kubeconform -strict -summary -kubernetes-version "$K8S_SCHEMA" "$REPO/kubernetes"
  check "Argo CD Applications are valid resources" kubeconform -strict -summary -kubernetes-version "$K8S_SCHEMA" \
    -schema-location default -schema-location "$CRD_CATALOG" \
    "$REPO/gitops/dev/root-application.yaml" "$REPO/gitops/dev/apps"
  if command -v yamllint >/dev/null; then
    check "yamllint" yamllint -d '{extends: relaxed, rules: {line-length: disable}}' "$REPO/kubernetes" "$REPO/gitops" "$REPO/helm/sample-service/Chart.yaml" "$REPO/helm/sample-service/values.yaml"
  fi
}

# load_image image   Loads a local image into the kind nodes from a
# single-platform archive. `kind load docker-image` fails with the containerd
# image store of recent Docker releases, which exports every platform.
load_image() {
  local arch archive
  arch="$(docker version --format '{{.Server.Arch}}')"
  archive="$(mktemp)"
  docker save --platform "linux/${arch}" "$1" -o "$archive"
  kind load image-archive "$archive" --name "$CLUSTER" >/dev/null
  rm -f "$archive"
}

live_checks() {
  echo "== live checks in kind"
  need kind
  need kubectl
  need docker
  local created attempt

  if [ "$REUSE" = "1" ] && kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    info "reusing the existing kind cluster"
    CLUSTER_UP=1
  else
    created=0
    for attempt in 1 2 3; do
      kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
      if kind create cluster --name "$CLUSTER" --config "$REPO/tests/kind/kind-config.yaml" --wait 600s >/dev/null 2>&1; then
        created=1
        break
      fi
      info "kind cluster creation failed, attempt $attempt of 3"
    done
    if [ "$created" = "1" ]; then
      CLUSTER_UP=1
      pass "kind cluster created with one control plane and two workers"
    else
      fail "kind cluster could not be created"
      return
    fi
  fi

  check "nodes and DNS are ready" wait_cluster

  docker build -q -t sample-service:kind "$REPO/applications/sample-service" >/dev/null
  docker pull -q --platform "linux/$(docker version --format '{{.Server.Arch}}')" busybox:1.36.1 >/dev/null
  load_image sample-service:kind
  load_image busybox:1.36.1
  pass "images built and loaded"

  check "cluster rules apply" retry 3 k apply -R -f "$REPO/kubernetes"
  # The PodMonitor needs the managed Prometheus add-on, which kind does not have, so the
  # install turns scraping off. The static checks still render and validate it.
  check "chart installs and rolls out" retry 3 bash -c "helm --kube-context '$CTX' upgrade --install sample-service '$REPO/helm/sample-service' -n apps \
    -f '$REPO/gitops/dev/values/sample-service.yaml' --set ingress.enabled=false --set metrics.scrape.enabled=false \
    --set image.repository=sample-service --set image.tag=kind --set image.pullPolicy=Never --wait --timeout 150s"

  local ready nodes
  ready="$(k -n apps get deployment sample-service -o jsonpath='{.status.readyReplicas}' || true)"
  expect "two replicas are ready" "$ready" "2"
  nodes="$(k -n apps get pods -l app.kubernetes.io/name=sample-service -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l | tr -d ' ' || true)"
  expect "replicas run on two different nodes" "$nodes" "2"

  local ports
  ports="$(k -n apps get service sample-service -o jsonpath='{.spec.ports[*].port}' || true)"
  expect "the Service exposes port 80 only, not the admin port" "$ports" "80"

  # Talk to one pod directly through a port-forward.
  local pod
  pod="$(k -n apps get pods -l app.kubernetes.io/name=sample-service -o jsonpath='{.items[0].metadata.name}' || true)"
  k -n apps port-forward "pod/$pod" 18080:8080 18081:8081 >/dev/null 2>&1 &
  PIDS+=("$!")
  for _ in $(seq 1 20); do
    curl -fs localhost:18080/healthz >/dev/null 2>&1 && break
    sleep 0.5
  done

  check "GET /healthz answers" curl -fs localhost:18080/healthz
  check "GET /readyz answers" curl -fs localhost:18080/readyz
  check "GET /work answers 200 with no errors set" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' localhost:18080/work)\" = 200 ]"
  check "the admin port sets the error rate" curl -fs -X PUT -d '{"error_rate":1}' localhost:18081/admin/config
  check "GET /work answers 500 when the error rate is 1" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' localhost:18080/work)\" = 500 ]"
  check "the admin port resets the error rate" curl -fs -X PUT -d '{"error_rate":0}' localhost:18081/admin/config
  check "the API port does not serve the admin path" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -X PUT -d '{}' localhost:18080/admin/config)\" = 404 ]"

  check "Pod Security rejects a privileged pod in apps" bash -c "! kubectl --context '$CTX' -n apps run privileged-probe --image=busybox:1.36.1 --privileged --restart=Never --dry-run=server"

  local defaults
  defaults="$(
    k -n apps apply --dry-run=server -o jsonpath='{.spec.containers[0].resources.requests.cpu}' -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: limits-probe
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: busybox:1.36.1
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ALL]
EOF
  )" || true
  expect "the limit range gives a container default requests" "$defaults" "25m"

  check "the limit range rejects a container above its maximum" bash -c "! kubectl --context '$CTX' -n apps apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: too-big-probe
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: busybox:1.36.1
      resources:
        requests:
          cpu: 600m
          memory: 64Mi
        limits:
          cpu: 600m
          memory: 64Mi
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ALL]
EOF"

  local used
  used="$(k -n apps get resourcequota apps -o jsonpath='{.status.used.pods}' || true)"
  expect "the resource quota counts the two pods" "$used" "2"

  # Network policy. kind may not enforce it, so these lines are information.
  k create namespace app-routing-system >/dev/null 2>&1 || true
  local blocked allowed reached
  reached="$(probe_http default netpol-denied http://sample-service.apps.svc/healthz)"
  case "$reached" in
    yes) blocked="no" ;;
    no) blocked="yes" ;;
    *) blocked="unknown" ;;
  esac
  # The network plugin can take a few seconds to program a new rule, so the
  # allowed path is tried up to three times.
  allowed="unknown"
  for _ in 1 2 3; do
    allowed="$(probe_http app-routing-system netpol-allowed http://sample-service.apps.svc/healthz)"
    [ "$allowed" = "yes" ] && break
    sleep 5
  done
  info "from a pod in the default namespace the service is blocked: $blocked"
  info "from a pod in app-routing-system the service is reachable: $allowed"
  if [ "$blocked" = "yes" ] && [ "$allowed" = "yes" ]; then
    pass "network policy is enforced on kind and the allowed path works"
  else
    info "network policy is not shown to be enforced on kind. Enforcement on AKS is checked in a live session"
  fi
}

# bootstrap_checks   Runs the bootstrap step of infrastructure/session.sh against
# the kind cluster and checks what it installs. The step uses the kubectl context
# of the kind cluster. Argo CD syncs the cluster rules from the main branch on
# GitHub, so this part needs network access.
bootstrap_checks() {
  echo "== bootstrap checks in kind"
  [ "$CLUSTER_UP" = "1" ] || {
    fail "no kind cluster for the bootstrap checks"
    return
  }
  local session="$REPO/infrastructure/session.sh" out
  # The sample service is installed by Argo CD from here on.
  helm --kube-context "$CTX" uninstall sample-service -n apps >/dev/null 2>&1 || true

  if out="$(PP_KUBE_CONTEXT="$CTX" "$session" bootstrap 2>&1)"; then
    pass "bootstrap step runs"
  else
    fail "bootstrap step runs"
    echo "$out" | tail -5
    return
  fi
  case "$out" in
    *"ingress range is not set"*) pass "the ingress range is skipped on a cluster without the add-on" ;;
    *) fail "the ingress range message was not found" ;;
  esac

  expect "the Argo CD server is available" "$(k -n argocd get deployment argocd-server -o jsonpath='{.status.availableReplicas}' || true)" "1"
  expect "the Argo CD application controller is ready" "$(k -n argocd get statefulset argocd-application-controller -o jsonpath='{.status.readyReplicas}' || true)" "1"
  expect "the ApplicationSet controller runs no replica" "$(k -n argocd get deployment argocd-applicationset-controller -o jsonpath='{.spec.replicas}' || true)" "0"
  check "Dex is not installed" bash -c "! kubectl --context '$CTX' -n argocd get deployment argocd-dex-server"
  check "the root Application exists" k -n argocd get application root
  check "the admin credential exists in the cluster" k -n argocd get secret argocd-initial-admin-secret

  local state="" _
  for _ in $(seq 1 60); do
    state="$(k -n argocd get application cluster-rules -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
    [ "$state" = "Synced/Healthy" ] && break
    sleep 5
  done
  expect "Argo CD syncs the cluster rules from Git" "$state" "Synced/Healthy"

  check "the credential is not printed when the output is not a terminal" bash -c "PP_KUBE_CONTEXT='$CTX' '$session' argocd-password; [ \$? = 2 ]"
  # The credential is read through a pseudo terminal and only its length is checked.
  check "the credential is printed on a terminal" env PP_KUBE_CONTEXT="$CTX" SESSION="$session" python3 -I -c '
import os, pty
data = bytearray()
def read(fd):
    chunk = os.read(fd, 1024)
    data.extend(chunk)
    return chunk
status = pty.spawn([os.environ["SESSION"], "argocd-password"], read)
raise SystemExit(0 if os.waitstatus_to_exitcode(status) == 0 and len(data.strip()) >= 8 else 1)
'

  check "the bootstrap step can be repeated" env PP_KUBE_CONTEXT="$CTX" "$session" bootstrap
}

# ingress_range_checks   Checks the part of the bootstrap step that limits the ingress
# to the maintainer's range. A stand-in for the add-on's resource is created, so
# the step takes its code path. This shows the step and not the add-on.
ingress_range_checks() {
  echo "== ingress range checks in kind"
  [ "$CLUSTER_UP" = "1" ] || {
    fail "no kind cluster for the ingress range checks"
    return
  }
  local session="$REPO/infrastructure/session.sh"
  k apply -f - >/dev/null <<'EOF2'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nginxingresscontrollers.approuting.kubernetes.azure.com
spec:
  group: approuting.kubernetes.azure.com
  scope: Cluster
  names:
    plural: nginxingresscontrollers
    singular: nginxingresscontroller
    kind: NginxIngressController
    listKind: NginxIngressControllerList
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
EOF2
  k wait --for=condition=Established crd/nginxingresscontrollers.approuting.kubernetes.azure.com --timeout=60s >/dev/null
  k apply -f - >/dev/null <<'EOF2'
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: NginxIngressController
metadata:
  name: default
spec:
  controllerNamePrefix: nginx
EOF2
  check "the step stops when no ingress range is given" bash -c "env -u TF_VAR_api_authorized_ip_ranges -u PP_INGRESS_ALLOWED_RANGES PP_KUBE_CONTEXT='$CTX' '$session' bootstrap ingress; [ \$? = 2 ]"
  check "the step stops when the ingress range is open to everyone" bash -c "PP_INGRESS_ALLOWED_RANGES=0.0.0.0/0 PP_KUBE_CONTEXT='$CTX' '$session' bootstrap ingress; [ \$? = 2 ]"
  check "the step sets the ingress range" env PP_INGRESS_ALLOWED_RANGES=203.0.113.10/32 PP_KUBE_CONTEXT="$CTX" "$session" bootstrap ingress
  expect "the range is on the controller's load balancer annotations" \
    "$(k get nginxingresscontroller default -o jsonpath='{.spec.loadBalancerAnnotations.service\.beta\.kubernetes\.io/azure-allowed-ip-ranges}' || true)" "203.0.113.10/32"
  k delete nginxingresscontroller default >/dev/null 2>&1 || true
  k delete crd nginxingresscontrollers.approuting.kubernetes.azure.com >/dev/null 2>&1 || true
}

static_checks
if [ "$STATIC_ONLY" = "0" ]; then
  live_checks
  ingress_range_checks
  if [ "$BOOTSTRAP" = "1" ]; then
    bootstrap_checks
  fi
fi

if [ "$FAILED" = "0" ]; then
  echo "result: all required checks passed"
else
  echo "result: at least one check failed"
  exit 1
fi
