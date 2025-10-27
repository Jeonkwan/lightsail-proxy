#!/usr/bin/env bash
set -euo pipefail

umask 022

SOLUTION="trojan-go"
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
Usage: setup.sh --username <name> --domain <domain> --subdomain <sub> \
                --public-ip <ip> --ddns-password <token> --uuid <uuid> \
                --asset-base-url <url>

Downloads the Trojan-Go Ansible playbook and executes it locally.
USAGE
}

USERNAME=""
DOMAIN=""
SUBDOMAIN=""
PUBLIC_IP=""
DDNS_PASSWORD=""
UUID=""
ASSET_BASE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --subdomain)
      SUBDOMAIN="$2"
      shift 2
      ;;
    --public-ip)
      PUBLIC_IP="$2"
      shift 2
      ;;
    --ddns-password)
      DDNS_PASSWORD="$2"
      shift 2
      ;;
    --uuid)
      UUID="$2"
      shift 2
      ;;
    --asset-base-url)
      ASSET_BASE_URL="$2"
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

if [[ -z "$USERNAME" || -z "$DOMAIN" || -z "$SUBDOMAIN" || -z "$PUBLIC_IP" || -z "$DDNS_PASSWORD" || -z "$UUID" || -z "$ASSET_BASE_URL" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

WORK_DIR="/opt/lightsail-proxy/${SOLUTION}"
PLAYBOOK_PATH="${WORK_DIR}/playbook.yml"
mkdir -p "${WORK_DIR}"

fetch_asset() {
  local url="$1"
  local dest="$2"
  local tmp
  tmp=$(mktemp)
  log "Downloading ${url}"
  curl -fsSL "$url" -o "$tmp"
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    log "Asset already up to date at ${dest}"
    rm -f "$tmp"
  else
    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
    chmod 0644 "$dest"
  fi
}

fetch_asset "${ASSET_BASE_URL}/playbook.yml" "$PLAYBOOK_PATH"

EXTRA_VARS_FILE=$(mktemp)
cleanup() {
  rm -f "$EXTRA_VARS_FILE"
}
trap cleanup EXIT

export EXTRA_USERNAME="$USERNAME"
export EXTRA_DOMAIN="$DOMAIN"
export EXTRA_SUBDOMAIN="$SUBDOMAIN"
export EXTRA_PUBLIC_IP="$PUBLIC_IP"
export EXTRA_DDNS_PASSWORD="$DDNS_PASSWORD"
export EXTRA_UUID="$UUID"
python3 - <<'PY' > "$EXTRA_VARS_FILE"
import json, os, sys
payload = {
    "username": os.environ["EXTRA_USERNAME"],
    "domain_name": os.environ["EXTRA_DOMAIN"],
    "subdomain_name": os.environ["EXTRA_SUBDOMAIN"],
    "public_ip": os.environ["EXTRA_PUBLIC_IP"],
    "namecheap_ddns_password": os.environ["EXTRA_DDNS_PASSWORD"],
    "proxy_server_uuid": os.environ["EXTRA_UUID"],
}
json.dump(payload, sys.stdout)
PY
unset EXTRA_USERNAME EXTRA_DOMAIN EXTRA_SUBDOMAIN EXTRA_PUBLIC_IP EXTRA_DDNS_PASSWORD EXTRA_UUID

log "Running Ansible playbook for ${SOLUTION}"
ANSIBLE_STDOUT_CALLBACK=default \
ANSIBLE_RETRY_FILES_ENABLED=0 \
ansible-playbook -vvv \
  --connection=local \
  --inventory "127.0.0.1," \
  --limit 127.0.0.1 \
  --extra-vars "@${EXTRA_VARS_FILE}" \
  "$PLAYBOOK_PATH"

log "${SOLUTION} setup completed"
