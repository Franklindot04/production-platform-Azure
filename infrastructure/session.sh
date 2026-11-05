#!/usr/bin/env bash
# Creates, destroys and checks the session layer of an environment.
# Usage: session.sh <up|down|check> [env] [--apply|--yes]
#   up              Plan the session root. The plan is saved outside the repository.
#   up --apply      Apply the saved plan. It bills until the session layer is destroyed.
#   down            Show the destroy plan.
#   down --yes      Destroy the session root.
#   check           List every resource by resource group and report what remains.
# env is dev, staging or prod. Default: dev.
# Exit codes: 0 nothing remains, 1 something remains, 2 error or wrong use.
# Output is masked: GUIDs and every /32 host range are replaced. See infrastructure/README.md.
set -euo pipefail

STEP="${1:-}"
shift || true

ENV_NAME="dev"
FLAG=""
for arg in "$@"; do
  case "$arg" in
    dev | staging | prod) ENV_NAME="$arg" ;;
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
plan_file() {
  local dir="${PP_PLAN_DIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd)"
  case "$dir/" in
    "${REPO_DIR}/"*)
      echo "PP_PLAN_DIR must be outside the repository" >&2
      exit 2
      ;;
  esac
  echo "${dir}/pp-${ENV_NAME}-session.tfplan"
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

case "$STEP" in
  up) step_up ;;
  down) step_down ;;
  check)
    build_mask
    step_check
    ;;
  *)
    echo "usage: session.sh <up|down|check> [env] [--apply|--yes]" >&2
    exit 2
    ;;
esac
