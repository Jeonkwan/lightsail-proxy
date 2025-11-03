#!/usr/bin/env bash
set -euo pipefail

umask 022

SOLUTION="less-vision"
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
Usage: setup.sh --domain <domain> --subdomain <sub> --uuid <uuid> --email <email> [options]

Options:
  --repo-url <url>       Git repository URL for less-vision (default: https://github.com/Jeonkwan/less-vision.git)
  --repo-branch <name>   Git branch or tag to checkout (default: main)
  --asset-base-url <url> Reserved for future use; ignored for now.
USAGE
}

DOMAIN=""
SUBDOMAIN=""
UUID=""
EMAIL=""
REPO_URL="https://github.com/Jeonkwan/less-vision.git"
REPO_BRANCH="main"
ASSET_BASE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --subdomain)
      SUBDOMAIN="$2"
      shift 2
      ;;
    --uuid)
      UUID="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
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

if [[ -z "$DOMAIN" || -z "$UUID" || -z "$EMAIL" ]]; then
  echo "--domain, --uuid, and --email are required." >&2
  usage
  exit 1
fi

FQDN="$DOMAIN"
if [[ -n "$SUBDOMAIN" ]]; then
  FQDN="${SUBDOMAIN}.${DOMAIN}"
fi

BASE_DIR="/opt/lightsail-proxy/${SOLUTION}"
PROJECT_ROOT="/opt/xray"
COMPOSE_PROJECT_DIRECTORY="${PROJECT_ROOT}/compose"
XRAY_CONFIG_DIR="${PROJECT_ROOT}/xray"
XRAY_CONFIG_FILE="config.json"
XRAY_COMPOSE_FILE="${COMPOSE_PROJECT_DIRECTORY}/docker-compose.yml"
REPO_DIR="${BASE_DIR}/repo"
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

sync_repo

EXTRA_VARS_FILE=$(mktemp)
cleanup() {
  rm -f "$EXTRA_VARS_FILE"
}
trap cleanup EXIT

export EXTRA_FQDN="$FQDN"
export EXTRA_EMAIL="$EMAIL"
export EXTRA_UUID="$UUID"
export EXTRA_COMPOSE_PROJECT_DIRECTORY="$COMPOSE_PROJECT_DIRECTORY"
export EXTRA_XRAY_CONFIG_DIR="$XRAY_CONFIG_DIR"
export EXTRA_XRAY_CONFIG_FILE="$XRAY_CONFIG_FILE"
export EXTRA_XRAY_COMPOSE_FILE="$XRAY_COMPOSE_FILE"
python3 - <<'PY' > "$EXTRA_VARS_FILE"
import json, os, sys
payload = {
    "xray_domain": os.environ["EXTRA_FQDN"],
    "xray_email": os.environ["EXTRA_EMAIL"],
    "xray_uuid": os.environ["EXTRA_UUID"],
    "compose_project_directory": os.environ["EXTRA_COMPOSE_PROJECT_DIRECTORY"],
    "xray_config_dir": os.environ["EXTRA_XRAY_CONFIG_DIR"],
    "xray_config_file": os.environ["EXTRA_XRAY_CONFIG_FILE"],
    "xray_compose_file": os.environ["EXTRA_XRAY_COMPOSE_FILE"],
}
json.dump(payload, sys.stdout)
PY
unset EXTRA_FQDN EXTRA_EMAIL EXTRA_UUID \
  EXTRA_COMPOSE_PROJECT_DIRECTORY EXTRA_XRAY_CONFIG_DIR \
  EXTRA_XRAY_CONFIG_FILE EXTRA_XRAY_COMPOSE_FILE

log "Running Ansible playbook for ${SOLUTION}"
(
  cd "$REPO_DIR"
  ANSIBLE_STDOUT_CALLBACK=default \
  ANSIBLE_RETRY_FILES_ENABLED=0 \
  ANSIBLE_CONFIG="$REPO_DIR/ansible.cfg" \
  ansible-playbook -vvv \
    --extra-vars "@${EXTRA_VARS_FILE}" \
    ansible/playbooks/site.yml
)

log "${SOLUTION} setup completed for ${FQDN}"
