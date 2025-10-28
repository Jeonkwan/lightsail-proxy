#!/usr/bin/env bash
set -euo pipefail

umask 022

SOLUTION="less-vision-reality"
LOG_DIR="/var/log/lightsail-proxy"
LOG_FILE="${LOG_DIR}/${SOLUTION}.log"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
chmod 0644 "${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() {
  printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

on_error() {
  local lineno="$1"
  echo "[$(date --iso-8601=seconds)] ERROR: ${SOLUTION} setup failed at line ${lineno}" >&2
}

trap 'on_error ${LINENO}' ERR

usage() {
  cat <<'USAGE'
Usage: setup.sh --uuid <uuid> --xray-short-ids <id1,id2,...> --xray-private-key <key> --xray-public-key <key> [options]

Options:
  --repo-url <url>     Git repository URL for less-vision-reality (default: https://github.com/Jeonkwan/less-vision-reality.git)
  --repo-branch <name> Git branch or tag to checkout (default: main)
  --xray-sni <domain>  Optional decoy SNI/domain forwarded to the playbook (default: web.wechat.com)
USAGE
}

UUID=""
XRAY_SHORT_IDS_RAW=""
XRAY_PRIVATE_KEY=""
XRAY_PUBLIC_KEY=""
XRAY_SNI="web.wechat.com"
REPO_URL="https://github.com/Jeonkwan/less-vision-reality.git"
REPO_BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uuid)
      UUID="$2"
      shift 2
      ;;
    --xray-short-ids)
      XRAY_SHORT_IDS_RAW="$2"
      shift 2
      ;;
    --xray-private-key)
      XRAY_PRIVATE_KEY="$2"
      shift 2
      ;;
    --xray-public-key)
      XRAY_PUBLIC_KEY="$2"
      shift 2
      ;;
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    --repo-branch)
      REPO_BRANCH="$2"
      shift 2
      ;;
    --xray-sni)
      XRAY_SNI="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$UUID" || -z "$XRAY_SHORT_IDS_RAW" || -z "$XRAY_PRIVATE_KEY" || -z "$XRAY_PUBLIC_KEY" ]]; then
  echo "--uuid, --xray-short-ids, --xray-private-key, and --xray-public-key are required." >&2
  usage
  exit 1
fi

BASE_DIR="/opt/lightsail-proxy/${SOLUTION}"
REPO_DIR="${BASE_DIR}/repo"
CREDENTIALS_FILE="${BASE_DIR}/credentials.json"
mkdir -p "$BASE_DIR"

sync_repo() {
  export GIT_TERMINAL_PROMPT=0
  if [[ -d "${REPO_DIR}/.git" ]]; then
    log "Updating ${REPO_URL} (${REPO_BRANCH})"
    git -C "$REPO_DIR" fetch --depth 1 origin "$REPO_BRANCH"
    git -C "$REPO_DIR" reset --hard "origin/${REPO_BRANCH}"
  else
    rm -rf "$REPO_DIR"
    log "Cloning ${REPO_URL} (${REPO_BRANCH})"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
}

convert_short_ids_to_json() {
  python3 - <<'PY'
import json
import os
import sys
raw = os.environ.get("SHORT_IDS_RAW", "")
short_ids = [item.strip() for item in raw.split(',') if item.strip()]
if not short_ids:
    raise SystemExit("At least one short ID must be provided")
json.dump(short_ids, sys.stdout)
PY
}

sync_repo

export SHORT_IDS_RAW="$XRAY_SHORT_IDS_RAW"
XRAY_SHORT_IDS_JSON=$(convert_short_ids_to_json)
unset SHORT_IDS_RAW

EXTRA_VARS_FILE=$(mktemp)
INVENTORY_FILE=$(mktemp)
cleanup() {
  rm -f "$EXTRA_VARS_FILE" "$INVENTORY_FILE"
}
trap cleanup EXIT

export EXTRA_UUID="$UUID"
export EXTRA_SHORT_IDS_JSON="$XRAY_SHORT_IDS_JSON"
export EXTRA_PRIVATE_KEY="$XRAY_PRIVATE_KEY"
export EXTRA_PUBLIC_KEY="$XRAY_PUBLIC_KEY"
export EXTRA_SNI="$XRAY_SNI"
python3 - <<'PY' > "$EXTRA_VARS_FILE"
import json
import os
import sys
payload = {
    "xray_uuid": os.environ["EXTRA_UUID"],
    "xray_short_ids": json.loads(os.environ["EXTRA_SHORT_IDS_JSON"]),
    "xray_reality_private_key": os.environ["EXTRA_PRIVATE_KEY"],
    "xray_reality_public_key": os.environ["EXTRA_PUBLIC_KEY"],
    "xray_sni": os.environ["EXTRA_SNI"],
}
json.dump(payload, sys.stdout)
PY
unset EXTRA_UUID EXTRA_SHORT_IDS_JSON EXTRA_PRIVATE_KEY EXTRA_PUBLIC_KEY EXTRA_SNI

log "Persisting credentials to ${CREDENTIALS_FILE}"
export CREDS_UUID="$UUID"
export CREDS_SHORT_IDS_JSON="$XRAY_SHORT_IDS_JSON"
export CREDS_PRIVATE_KEY="$XRAY_PRIVATE_KEY"
export CREDS_PUBLIC_KEY="$XRAY_PUBLIC_KEY"
export CREDS_SNI="$XRAY_SNI"
python3 - <<'PY' > "$CREDENTIALS_FILE"
import json
import os
import sys
from datetime import datetime

payload = {
    "uuid": os.environ["CREDS_UUID"],
    "short_ids": json.loads(os.environ["CREDS_SHORT_IDS_JSON"]),
    "private_key": os.environ["CREDS_PRIVATE_KEY"],
    "public_key": os.environ["CREDS_PUBLIC_KEY"],
    "sni": os.environ["CREDS_SNI"],
    "generated_at": datetime.utcnow().isoformat() + "Z",
}
json.dump(payload, sys.stdout, indent=2)
PY
unset CREDS_UUID CREDS_SHORT_IDS_JSON CREDS_PRIVATE_KEY CREDS_PUBLIC_KEY CREDS_SNI
chmod 0600 "$CREDENTIALS_FILE"

cat <<'EOF' > "$INVENTORY_FILE"
[xray_servers]
127.0.0.1 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
EOF

log "Running Ansible playbook for ${SOLUTION}"
(
  cd "$REPO_DIR"
  ANSIBLE_STDOUT_CALLBACK=default \
  ANSIBLE_RETRY_FILES_ENABLED=0 \
  ANSIBLE_CONFIG="$REPO_DIR/ansible.cfg" \
  ansible-playbook -vvv \
    -i "$INVENTORY_FILE" \
    --extra-vars "@${EXTRA_VARS_FILE}" \
    ansible/site.yml
)

log "${SOLUTION} setup completed"
