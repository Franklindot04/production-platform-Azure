#!/usr/bin/env bash
# Creates, destroys and checks the session layer of an environment.
# Usage: session.sh <up|down|check|bootstrap|argocd-password> [env] [part] [--apply|--yes]
#   up              Plan the session root. The plan is saved outside the repository.
#   up --apply      Apply the saved plan. It bills until the session layer is destroyed.
#   down            Show the destroy plan.
#   down --yes      Destroy the session root.
#   check           List every resource by resource group and report what remains.
#   bootstrap       Install Argo CD with Helm, set the ingress source range, and apply
#                   the root Application, set the identity of the sample service, then create
#                   the cluster secret for the Collector.
#                   It can be repeated. A part (argocd, ingress, root, identity or secrets) runs only
#                   that part, for example `bootstrap ingress` to set the ingress range
#                   again after the maintainer's address changed. The secrets part reads the
#                   Application Insights connection string from the persistent root at run
#                   time and creates the secret appinsights-connection in the namespace
#                   observability. The value only travels through pipes. It is not printed,
#                   masked, stored or written to a file. It is skipped on a kind cluster in a
#                   full bootstrap, and `bootstrap secrets` stops there (PP_KUBE_CONTEXT).
#                   The identity part reads the client ID and the vault name from the
#                   persistent root and the tenant ID from the signed-in Azure account, at run
#                   time. It sets them as Helm parameters, with the Key Vault mount turned on,
#                   on the Argo CD Application sample-service (ADR 0029). No value is printed,
#                   written to a file or stored by the script. It is skipped on a kind cluster
#                   in a full bootstrap, and `bootstrap identity` stops there.
#   argocd-password Print the Argo CD admin credential to the terminal. It is generated
#                   by Argo CD, read from the cluster when asked, and never stored.
# env is dev, staging or prod. Default: dev.
# bootstrap and argocd-password use the administrator credential of the session cluster.
# PP_KUBE_CONTEXT=<context> uses an existing kubectl context instead, for a kind cluster.
# The ingress source range comes from PP_INGRESS_ALLOWED_RANGES (comma separated) or from
# TF_VAR_api_authorized_ip_ranges. It is not stored.
# up needs the object ID of the Entra ID admin group in TF_VAR_cluster_admin_group_object_id
# (ADR 0021). It is set at run time and is not stored.
# Exit codes: 0 nothing remains, 1 something remains, 2 error or wrong use.
# Output is masked: GUIDs and every /32 host range are replaced. See infrastructure/README.md.
set -euo pipefail

STEP="${1:-}"
shift || true

ENV_NAME="dev"
FLAG=""
PART="all"
for arg in "$@"; do
  case "$arg" in
    dev | staging | prod) ENV_NAME="$arg" ;;
    argocd | ingress | root | identity | secrets) PART="$arg" ;;
    --apply | --yes) FLAG="$arg" ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT="${SCRIPT_DIR}/environments/${ENV_NAME}/session"
PERSISTENT_ROOT="${SCRIPT_DIR}/environments/${ENV_NAME}/persistent"
NAME_FILE="${SCRIPT_DIR}/bootstrap/.state-account-name"
STATE_RG="pp-shared-state-rg"

# Build the sed expressions that hide GUIDs and the authorized range.
MASK_SED=(-E
  -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/xxxx/g'
  -e 's#([0-9]{1,3}\.){3}[0-9]{1,3}/32#<authorized-ip>/32#g')
build_mask() {
  local ip
  while read -r ip; do
    [ -n "$ip" ] || continue
    MASK_SED+=(-e "s/${ip//./\\.}/<authorized-ip>/g")
  done < <(printf '%s' "${TF_VAR_api_authorized_ip_ranges:-}" | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' || true)
}
mask() {
  sed "${MASK_SED[@]}"
}

need_terraform_inputs() {
  command -v terraform >/dev/null || {
    echo "terraform is not installed" >&2
    exit 2
  }
  [ -d "$ROOT" ] || {
    echo "no session root for ${ENV_NAME}" >&2
    exit 2
  }
  [ -f "$NAME_FILE" ] || {
    echo "missing ${NAME_FILE}. Run infrastructure/bootstrap/bootstrap.sh first." >&2
    exit 2
  }
  ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  export ARM_SUBSCRIPTION_ID
}

# The plan file holds the authorized range, so it must stay outside the repository.
plan_dir() {
  local dir="${PP_PLAN_DIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd)"
  case "$dir/" in
    "${REPO_DIR}/"*)
      echo "PP_PLAN_DIR must be outside the repository" >&2
      exit 2
      ;;
  esac
  echo "$dir"
}

plan_file() {
  echo "$(plan_dir)/pp-${ENV_NAME}-session.tfplan"
}

tf_init() {
  terraform -chdir="$ROOT" init -input=false -no-color -reconfigure \
    -backend-config="resource_group_name=${STATE_RG}" \
    -backend-config="storage_account_name=$(cat "$NAME_FILE")" 2>&1 | mask
}

step_up() {
  if [ -z "${TF_VAR_api_authorized_ip_ranges:-}" ]; then
    echo "Set TF_VAR_api_authorized_ip_ranges to a JSON list of CIDR ranges." >&2
    exit 2
  fi
  if [ -z "${TF_VAR_cluster_admin_group_object_id:-}" ]; then
    echo "Set TF_VAR_cluster_admin_group_object_id to the object ID of the Entra ID admin group." >&2
    exit 2
  fi
  need_terraform_inputs
  build_mask
  local plan
  plan="$(plan_file)"
  tf_init
  if [ "$FLAG" = "--apply" ]; then
    [ -f "$plan" ] || {
      echo "No saved plan. Run 'session.sh up' first." >&2
      exit 2
    }
    terraform -chdir="$ROOT" apply -input=false -no-color "$plan" 2>&1 | mask
    echo "The session layer exists and bills until it is destroyed: session.sh down --yes"
  else
    terraform -chdir="$ROOT" plan -input=false -no-color -out="$plan" 2>&1 | mask
  fi
}

step_down() {
  # A destroy only needs a valid value, so use a documentation address if none is set.
  export TF_VAR_api_authorized_ip_ranges="${TF_VAR_api_authorized_ip_ranges:-[\"203.0.113.10/32\"]}"
  export TF_VAR_cluster_admin_group_object_id="${TF_VAR_cluster_admin_group_object_id:-00000000-0000-0000-0000-000000000000}"
  need_terraform_inputs
  build_mask
  tf_init
  if [ "$FLAG" = "--yes" ]; then
    terraform -chdir="$ROOT" destroy -input=false -no-color -auto-approve 2>&1 | mask
  else
    terraform -chdir="$ROOT" plan -destroy -input=false -no-color 2>&1 | mask
    echo "Nothing was destroyed. Use 'session.sh down --yes' to destroy."
  fi
}

step_check() {
  local groups_json res_json
  groups_json="$(az group list --query '[].name' -o json)"
  res_json="$(az resource list --query '[].{g:resourceGroup,t:type,n:name}' -o json)"
  PP_ENV="$ENV_NAME" PP_GROUPS="$groups_json" PP_RES="$res_json" python3 -I - <<'PY' | mask
import json
import os
import sys

env = os.environ["PP_ENV"]
groups = json.loads(os.environ["PP_GROUPS"])
resources = json.loads(os.environ["PP_RES"])

expected = {"pp-shared-state-rg", f"pp-{env}-persistent-rg"}
azure_made = {"networkwatcherrg"}
session = {f"pp-{env}-session-rg", f"pp-{env}-aks-nodes-rg"}
compute = {
    "microsoft.compute/virtualmachines",
    "microsoft.compute/virtualmachinescalesets",
    "microsoft.containerservice/managedclusters",
}
billed = {
    "public IP addresses": "microsoft.network/publicipaddresses",
    "load balancers": "microsoft.network/loadbalancers",
    "managed disks": "microsoft.compute/disks",
}


def short(resource_type):
    return resource_type.split("/")[-1]


by_group = {name: [] for name in groups}
for r in resources:
    by_group.setdefault(r["g"], []).append(r)

print("== resource groups")
for name in sorted(by_group, key=str.lower):
    items = by_group[name]
    counts = {}
    for r in items:
        counts[short(r["t"])] = counts.get(short(r["t"]), 0) + 1
    detail = ", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "empty"
    noun = "resource" if len(items) == 1 else "resources"
    print(f"{name}: {len(items)} {noun} ({detail})")
    if name.lower() not in {g.lower() for g in expected | azure_made}:
        for r in items:
            print(f"  {r['n']} ({short(r['t'])})")

remains = []


def report(label, found):
    if found:
        remains.append(label)
        print(f"{label}: REMAINS {found}")
    else:
        print(f"{label}: none")


print("== result")
lower_groups = {g.lower() for g in by_group}
report("session layer groups", sorted(g for g in by_group if g.lower() in session))
comp = {}
for r in resources:
    if r["t"].lower() in compute:
        comp[short(r["t"])] = comp.get(short(r["t"]), 0) + 1
report("compute", comp)
for label, rtype in billed.items():
    n = sum(1 for r in resources if r["t"].lower() == rtype)
    report(label, n or "")
allowed = {g.lower() for g in expected | azure_made | session}
report("unexpected resource groups", sorted(g for g in by_group if g.lower() not in allowed))
if "networkwatcherrg" in lower_groups:
    print("note: NetworkWatcherRG is created by Azure and is not counted")
for name in sorted(by_group):
    if name.lower() == f"pp-{env}-persistent-rg":
        print(f"note: {name} exists (persistent layer, not counted)")
sys.exit(1 if remains else 0)
PY
}

ARGOCD_NAMESPACE="argocd"
ARGOCD_CHART_VERSION="10.14.0"
ARGOCD_REPO="https://argoproj.github.io/argo-helm"
NGINX_CRD="nginxingresscontrollers.approuting.kubernetes.azure.com"

# kube_setup   Sets K and H to the kubectl and helm commands for the cluster.
# The kubeconfig of the session cluster is written outside the repository.
kube_setup() {
  command -v kubectl >/dev/null || {
    echo "kubectl is not installed" >&2
    exit 2
  }
  command -v helm >/dev/null || {
    echo "helm is not installed" >&2
    exit 2
  }
  if [ -n "${PP_KUBE_CONTEXT:-}" ]; then
    K=(kubectl --context "$PP_KUBE_CONTEXT")
    H=(helm --kube-context "$PP_KUBE_CONTEXT")
    return
  fi
  local kubeconfig
  kubeconfig="$(plan_dir)/kubeconfig-${ENV_NAME}"
  az aks get-credentials --admin --overwrite-existing --file "$kubeconfig" \
    -g "pp-${ENV_NAME}-session-rg" -n "pp-${ENV_NAME}-aks" >/dev/null
  chmod 600 "$kubeconfig"
  export KUBECONFIG="$kubeconfig"
  K=(kubectl)
  H=(helm)
}

# ingress_ranges   Prints the source ranges for the ingress as a comma separated
# list, or stops. The ingress is never left open by default.
ingress_ranges() {
  local ranges="${PP_INGRESS_ALLOWED_RANGES:-}"
  if [ -z "$ranges" ] && [ -n "${TF_VAR_api_authorized_ip_ranges:-}" ]; then
    ranges="$(python3 -I -c 'import json,sys; print(",".join(json.loads(sys.argv[1])))' "$TF_VAR_api_authorized_ip_ranges")"
  fi
  if [ -z "$ranges" ]; then
    echo "Set PP_INGRESS_ALLOWED_RANGES or TF_VAR_api_authorized_ip_ranges." >&2
    exit 2
  fi
  python3 -I -c 'import ipaddress,sys
for r in sys.argv[1].split(","):
    ipaddress.ip_network(r, strict=False)
    if r.endswith("/0"):
        raise SystemExit("a range of /0 is not allowed")' "$ranges" || {
    echo "The ingress ranges are not a list of CIDR ranges." >&2
    exit 2
  }
  echo "$ranges"
}

# set_ingress_range   Limits the managed NGINX controller to the maintainer's
# range through the annotations of its load balancer Service. On a cluster
# without the add-on, such as kind, there is nothing to set.
set_ingress_range() {
  if ! "${K[@]}" get crd "$NGINX_CRD" >/dev/null 2>&1; then
    echo "This cluster has no application routing add-on. The ingress range is not set."
    return 0
  fi
  local ranges patch i
  ranges="$(ingress_ranges)"
  for i in $(seq 1 60); do
    "${K[@]}" get nginxingresscontroller default >/dev/null 2>&1 && break
    [ "$i" = "60" ] && {
      echo "The default NginxIngressController does not exist." >&2
      exit 1
    }
    sleep 5
  done
  patch="$(python3 -I -c 'import json,sys; print(json.dumps({"spec": {"loadBalancerAnnotations": {"service.beta.kubernetes.io/azure-allowed-ip-ranges": sys.argv[1]}}}))' "$ranges")"
  "${K[@]}" patch nginxingresscontroller default --type merge -p "$patch" 2>&1 | mask
  echo "The ingress source range is set."
  # One replica uses less of the small capacity. If AKS refuses it, go on.
  "${K[@]}" patch nginxingresscontroller default --type merge \
    -p '{"spec":{"scaling":{"minReplicas":1,"maxReplicas":2}}}' 2>&1 | mask ||
    echo "warning: the scaling of the ingress controller was not changed"
}

# init_persistent   Initialises the backend of the persistent root. The output is discarded.
init_persistent() {
  need_terraform_inputs
  [ -d "$PERSISTENT_ROOT" ] || {
    echo "no persistent root for ${ENV_NAME}" >&2
    exit 2
  }
  terraform -chdir="$PERSISTENT_ROOT" init -input=false -no-color -reconfigure \
    -backend-config="resource_group_name=${STATE_RG}" \
    -backend-config="storage_account_name=$(cat "$NAME_FILE")" >/dev/null 2>&1 || {
    echo "Could not initialise the backend of the persistent root." >&2
    exit 1
  }
}

# create_collector_secret   Creates the secret appinsights-connection in the namespace
# observability from the connection string in the state of the persistent root.
# The value is never put in a variable or a file, and it is never printed or masked.
# It only travels through pipes.
create_collector_secret() {
  local i output_name="application_insights_connection_string"
  if [ -n "${PP_KUBE_CONTEXT:-}" ]; then
    echo "The secrets part reads Azure state, and a kind cluster has none." >&2
    echo "Create the secret appinsights-connection (key connection-string) by hand if it is needed there." >&2
    exit 2
  fi
  init_persistent
  for i in $(seq 1 60); do
    "${K[@]}" get namespace observability >/dev/null 2>&1 && break
    [ "$i" = "60" ] && {
      echo "The namespace observability does not exist. Check the cluster-rules Application." >&2
      exit 1
    }
    sleep 5
  done
  # First read: stop without printing anything if the output is empty or missing.
  terraform -chdir="$PERSISTENT_ROOT" output -raw "$output_name" 2>/dev/null |
    python3 -I -c 'import sys; sys.exit(0 if sys.stdin.buffer.read().strip() else 3)' || {
    echo "The persistent root has no connection string. Apply the persistent root first." >&2
    exit 1
  }
  # Second read: straight into the cluster.
  terraform -chdir="$PERSISTENT_ROOT" output -raw "$output_name" 2>/dev/null |
    "${K[@]}" -n observability create secret generic appinsights-connection \
      --from-file=connection-string=/dev/stdin --dry-run=client -o yaml 2>/dev/null |
    "${K[@]}" apply -f - >/dev/null 2>&1 || {
    echo "The secret appinsights-connection was not set." >&2
    exit 1
  }
  echo "The secret appinsights-connection is set in the namespace observability."
}

# set_sample_service_identity   Sets the Helm parameters of the Key Vault mount on the
# Argo CD Application sample-service (ADR 0029). The client ID and the vault name come
# from the outputs of the persistent root and the tenant ID from the signed-in account.
# They are passed to python in the environment, and the patch goes to kubectl on a pipe,
# so no value is on a command line. Nothing is printed, masked or written to a file.
set_sample_service_identity() {
  local i client_id vault_name tenant_id
  if [ -n "${PP_KUBE_CONTEXT:-}" ]; then
    echo "The identity part reads Azure state, and a kind cluster has none." >&2
    exit 2
  fi
  init_persistent
  client_id="$(terraform -chdir="$PERSISTENT_ROOT" output -raw sample_service_identity_client_id 2>/dev/null)" || client_id=""
  vault_name="$(terraform -chdir="$PERSISTENT_ROOT" output -raw key_vault_name 2>/dev/null)" || vault_name=""
  tenant_id="$(az account show --query tenantId -o tsv 2>/dev/null)" || tenant_id=""
  if [ -z "$client_id" ] || [ -z "$vault_name" ] || [ -z "$tenant_id" ]; then
    echo "Could not read the identity, the vault name or the tenant. Apply the persistent root and sign in to Azure." >&2
    exit 1
  fi
  for i in $(seq 1 60); do
    "${K[@]}" -n "$ARGOCD_NAMESPACE" get application sample-service >/dev/null 2>&1 && break
    [ "$i" = "60" ] && {
      echo "The Application sample-service does not exist. Check the root Application." >&2
      exit 1
    }
    sleep 5
  done
  PP_CLIENT_ID="$client_id" PP_TENANT_ID="$tenant_id" PP_VAULT_NAME="$vault_name" python3 -I -c '
import json
import os

def param(name, value, force_string=True):
    item = {"name": name, "value": value}
    if force_string:
        item["forceString"] = True
    return item

params = [
    param("vaultSecret.enabled", "true", False),
    param("vaultSecret.clientId", os.environ["PP_CLIENT_ID"]),
    param("vaultSecret.tenantId", os.environ["PP_TENANT_ID"]),
    param("vaultSecret.vaultName", os.environ["PP_VAULT_NAME"]),
]
print(json.dumps({"spec": {"source": {"helm": {"parameters": params}}}}))
' |
    "${K[@]}" -n "$ARGOCD_NAMESPACE" patch application sample-service --type merge \
      --patch-file /dev/stdin >/dev/null 2>&1 || {
    echo "The identity of the sample service was not set." >&2
    exit 1
  }
  echo "The Key Vault mount is turned on for the Application sample-service."
}

step_bootstrap() {
  local root_app="${REPO_DIR}/gitops/${ENV_NAME}/root-application.yaml"
  [ -f "$root_app" ] || {
    echo "no root Application for ${ENV_NAME}" >&2
    exit 2
  }
  build_mask
  kube_setup

  if [ "$PART" = "all" ] || [ "$PART" = "argocd" ]; then
    echo "== argo cd"
    "${H[@]}" upgrade --install argocd argo-cd --repo "$ARGOCD_REPO" --version "$ARGOCD_CHART_VERSION" \
      --namespace "$ARGOCD_NAMESPACE" --create-namespace \
      -f "${REPO_DIR}/gitops/bootstrap/argocd-values.yaml" --wait --timeout 10m 2>&1 | mask
  fi

  if [ "$PART" = "all" ] || [ "$PART" = "ingress" ]; then
    echo "== ingress range"
    set_ingress_range
  fi

  if [ "$PART" = "all" ] || [ "$PART" = "root" ]; then
    echo "== root application"
    "${K[@]}" apply -f "$root_app" 2>&1 | mask
  fi

  if [ "$PART" = "identity" ]; then
    echo "== identity"
    set_sample_service_identity
  elif [ "$PART" = "all" ]; then
    echo "== identity"
    if [ -n "${PP_KUBE_CONTEXT:-}" ]; then
      echo "Skipped: a kind cluster has no Azure state. The Key Vault mount stays off."
    else
      set_sample_service_identity
    fi
  fi

  if [ "$PART" = "secrets" ]; then
    echo "== secrets"
    create_collector_secret
  elif [ "$PART" = "all" ]; then
    echo "== secrets"
    if [ -n "${PP_KUBE_CONTEXT:-}" ]; then
      echo "Skipped: a kind cluster has no Azure state. Create the secret appinsights-connection by hand if it is needed."
    else
      create_collector_secret
    fi
  fi

  if [ "$PART" = "all" ]; then
    echo "Argo CD is installed and the root Application is applied."
    echo "Read the admin credential with: session.sh argocd-password"
    echo "Open the UI with: kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443"
  fi
}

step_argocd_password() {
  if [ ! -t 1 ]; then
    echo "Not printing the credential: the output is not a terminal." >&2
    exit 2
  fi
  kube_setup
  "${K[@]}" -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
  echo
}

case "$STEP" in
  up) step_up ;;
  down) step_down ;;
  check)
    build_mask
    step_check
    ;;
  bootstrap) step_bootstrap ;;
  argocd-password) step_argocd_password ;;
  *)
    echo "usage: session.sh <up|down|check|bootstrap|argocd-password> [env] [part] [--apply|--yes]" >&2
    exit 2
    ;;
esac
