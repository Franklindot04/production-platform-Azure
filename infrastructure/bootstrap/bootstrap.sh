#!/usr/bin/env bash
# Creates the Terraform state backend with the Azure CLI.
# Usage: bootstrap.sh [env] [step]
#   env   dev, staging or prod. Default: dev.
#   step  check, group, account, protect, container, role or verify.
#         Without a step, all steps run in that order.
# Every step skips work that already exists, so the script can be run again.
# See README.md in this folder and ADR 0003, 0004 and 0010.
set -euo pipefail

ENV_NAME="${1:-dev}"
STEP="${2:-all}"

case "$ENV_NAME" in
  dev | staging | prod) ;;
  *)
    echo "env must be dev, staging or prod" >&2
    exit 2
    ;;
esac

LOCATION="northeurope"
RG="pp-shared-state-rg"
CONTAINER="tfstate-${ENV_NAME}"
TAGS=("project=production-platform-azure" "env=shared" "managed-by=azure-cli")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME_FILE="${SCRIPT_DIR}/.state-account-name"

# Replace any GUID in output with xxxx.
mask() {
  sed -E 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/xxxx/g'
}

# Run an az command and mask its output. Errors are masked too.
az_masked() {
  az "$@" 2>&1 | mask
  return "${PIPESTATUS[0]}"
}

# Set ACCOUNT from the resource group, then the name file. Empty if none exists.
find_account() {
  ACCOUNT=""
  if [ "$(az group exists -n "$RG")" = "true" ]; then
    ACCOUNT="$(az storage account list -g "$RG" --query "[?starts_with(name, 'ppsharedstate')].name | [0]" -o tsv)"
  fi
  if [ -z "$ACCOUNT" ] && [ -f "$NAME_FILE" ]; then
    ACCOUNT="$(cat "$NAME_FILE")"
  fi
}

require_account() {
  find_account
  if [ -z "$ACCOUNT" ] || ! az storage account show -n "$ACCOUNT" -g "$RG" -o none 2>/dev/null; then
    echo "No state storage account found. Run the account step first." >&2
    exit 1
  fi
}

container_scope() {
  echo "$(az storage account show -n "$ACCOUNT" -g "$RG" --query id -o tsv)/blobServices/default/containers/${CONTAINER}"
}

step_check() {
  echo "== check"
  az_masked account show --query '{name:name,state:state}' -o json
  state="$(az account show --query state -o tsv)"
  if [ "$state" != "Enabled" ]; then
    echo "Subscription is not enabled" >&2
    exit 1
  fi
}

step_group() {
  echo "== group"
  if [ "$(az group exists -n "$RG")" = "true" ]; then
    echo "$RG exists, skipped"
    return
  fi
  az_masked group create -n "$RG" -l "$LOCATION" --tags "${TAGS[@]}" \
    --query '{name:name,location:location,tags:tags}' -o json
}

step_account() {
  echo "== account"
  find_account
  if [ -n "$ACCOUNT" ] && az storage account show -n "$ACCOUNT" -g "$RG" -o none 2>/dev/null; then
    echo "$ACCOUNT exists, skipped"
  else
    if [ -z "$ACCOUNT" ]; then
      suffix="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6 || true)"
      if [ "${#suffix}" -ne 6 ]; then
        echo "Could not draw a 6-character suffix" >&2
        exit 1
      fi
      ACCOUNT="ppsharedstate${suffix}"
    fi
    available="$(az storage account check-name -n "$ACCOUNT" --query nameAvailable -o tsv)"
    if [ "$available" != "true" ]; then
      echo "Name $ACCOUNT is not available. Delete ${NAME_FILE} and run again." >&2
      exit 1
    fi
    az_masked storage account create -n "$ACCOUNT" -g "$RG" -l "$LOCATION" \
      --sku Standard_LRS --kind StorageV2 --access-tier Hot \
      --min-tls-version TLS1_2 --https-only true \
      --allow-blob-public-access false --allow-shared-key-access false \
      --tags "${TAGS[@]}" \
      --query '{name:name,sku:sku.name,tls:minimumTlsVersion,sharedKey:allowSharedKeyAccess,publicBlob:allowBlobPublicAccess,httpsOnly:enableHttpsTrafficOnly}' -o json
  fi
  echo "$ACCOUNT" >"$NAME_FILE"
  echo "Account name written to ${NAME_FILE}"
}

step_protect() {
  echo "== protect"
  require_account
  az_masked storage account blob-service-properties update --account-name "$ACCOUNT" -g "$RG" \
    --enable-versioning true \
    --enable-delete-retention true --delete-retention-days 14 \
    --enable-container-delete-retention true --container-delete-retention-days 14 \
    --query '{versioning:isVersioningEnabled,blobDelete:deleteRetentionPolicy,containerDelete:containerDeleteRetentionPolicy}' -o json
}

step_container() {
  echo "== container"
  require_account
  if az storage container-rm show --storage-account "$ACCOUNT" -g "$RG" -n "$CONTAINER" -o none 2>/dev/null; then
    echo "$CONTAINER exists, skipped"
    return
  fi
  az_masked storage container-rm create --storage-account "$ACCOUNT" -g "$RG" -n "$CONTAINER" \
    --query '{name:name,publicAccess:publicAccess}' -o json
}

step_role() {
  echo "== role"
  require_account
  me="$(az ad signed-in-user show --query id -o tsv)"
  scope="$(container_scope)"
  existing="$(az role assignment list --assignee "$me" --scope "$scope" --role "Storage Blob Data Contributor" --query 'length(@)' -o tsv)"
  if [ "$existing" != "0" ]; then
    echo "Storage Blob Data Contributor on ${CONTAINER} exists, skipped"
    return
  fi
  az_masked role assignment create --assignee-object-id "$me" --assignee-principal-type User \
    --role "Storage Blob Data Contributor" --scope "$scope" \
    --query '{role:roleDefinitionName,principalType:principalType}' -o json
}

step_verify() {
  echo "== verify"
  require_account
  failed=0

  echo "-- resource group"
  az_masked group show -n "$RG" --query '{location:location,tags:tags}' -o json

  echo "-- storage account"
  az_masked storage account show -n "$ACCOUNT" -g "$RG" \
    --query '{sku:sku.name,tls:minimumTlsVersion,sharedKey:allowSharedKeyAccess,publicBlob:allowBlobPublicAccess,httpsOnly:enableHttpsTrafficOnly,tags:tags}' -o json

  echo "-- versioning and soft delete"
  az_masked storage account blob-service-properties show --account-name "$ACCOUNT" -g "$RG" \
    --query '{versioning:isVersioningEnabled,blobDelete:deleteRetentionPolicy,containerDelete:containerDeleteRetentionPolicy}' -o json

  echo "-- container"
  az_masked storage container-rm show --storage-account "$ACCOUNT" -g "$RG" -n "$CONTAINER" --query name -o tsv

  echo "-- role"
  me="$(az ad signed-in-user show --query id -o tsv)"
  az_masked role assignment list --assignee "$me" --scope "$(container_scope)" --query '[].roleDefinitionName' -o tsv

  echo "-- access with Entra ID (retries for up to 5 minutes while the role takes effect)"
  ok=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if az storage blob list --account-name "$ACCOUNT" -c "$CONTAINER" --auth-mode login -o none 2>/dev/null; then
      ok=1
      break
    fi
    sleep 30
  done
  if [ "$ok" = "1" ]; then
    echo "pass: blob list with Entra ID"
  else
    echo "fail: blob list with Entra ID"
    failed=1
  fi

  echo "-- access with the account key is refused"
  if az storage blob list --account-name "$ACCOUNT" -c "$CONTAINER" --auth-mode key -o none 2>/dev/null; then
    echo "fail: shared key access worked"
    failed=1
  else
    echo "pass: shared key access refused"
  fi

  exit "$failed"
}

run_step() {
  case "$1" in
    check) step_check ;;
    group) step_group ;;
    account) step_account ;;
    protect) step_protect ;;
    container) step_container ;;
    role) step_role ;;
    verify) step_verify ;;
    *)
      echo "unknown step: $1" >&2
      exit 2
      ;;
  esac
}

if [ "$STEP" = "all" ]; then
  for s in check group account protect container role verify; do
    run_step "$s"
  done
else
  run_step "$STEP"
fi
