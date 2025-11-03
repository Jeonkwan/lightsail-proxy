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
CERTIFICATES_DIR="${PROJECT_ROOT}/certificates"
XRAY_CERTIFICATE_PATH="${CERTIFICATES_DIR}/live/${FQDN}/fullchain.pem"
XRAY_PRIVATE_KEY_PATH="${CERTIFICATES_DIR}/live/${FQDN}/privkey.pem"
XRAY_CONTAINER_CERTIFICATE_PATH="/etc/ssl/live/${FQDN}/fullchain.pem"
XRAY_CONTAINER_PRIVATE_KEY_PATH="/etc/ssl/live/${FQDN}/privkey.pem"
LETSENCRYPT_IMAGE="certbot/certbot:latest"
LETSENCRYPT_STAGING="false"
FORCE_REGENERATE_CERTS="false"
XRAY_LOG_LEVEL="warning"
XRAY_INBOUND_PORT="443"
XRAY_SERVICE_PORT="${XRAY_INBOUND_PORT}"
XRAY_FLOW="xtls-rprx-vision"
XRAY_CLIENT_EMAIL="${EMAIL}"
XRAY_ALPN_JSON='["h2", "http/1.1"]'
XRAY_IMAGE="ghcr.io/xtls/xray-core:25.10.15"
XRAY_CONTAINER_USER="0:0"
XRAY_CONTAINER_NAME="xray"
XRAY_FAILURE_LOG_LINES="200"
DOCKER_COMPOSE_UP="true"
DOCKER_COMPOSE_DOWN_BEFORE_UP="true"
DOCKER_COMPOSE_REMOVE_ORPHANS="true"
XRAY_CONTAINER_CONFDIR="/usr/local/etc/xray"
XRAY_RESTART_POLICY="unless-stopped"
XRAY_HOST_PORT="${XRAY_INBOUND_PORT}"
XRAY_CONTAINER_PORT="${XRAY_SERVICE_PORT}"
XRAY_COMPOSE_ENVIRONMENT_JSON='{}'
XRAY_COMPOSE_NETWORKS_JSON='[]'
XRAY_SERVICE_ROOT="${PROJECT_ROOT}"
XRAY_SERVICE_NAME="${XRAY_CONTAINER_NAME}"
XRAY_CONFIG_PATH="${XRAY_CONFIG_DIR}"
XRAY_DEPLOY_WAIT_SECONDS="60"
XRAY_DEPLOY_RECOVERY_WAIT_SECONDS="30"
XRAY_DEPLOY_LOG_TAIL_LINES="300"
XRAY_COMMON_DOCKER_USER="ubuntu"
DOCKER_PREREQS_USER="${XRAY_COMMON_DOCKER_USER}"
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
export EXTRA_PROJECT_ROOT="$PROJECT_ROOT"
export EXTRA_CERTIFICATES_DIR="$CERTIFICATES_DIR"
export EXTRA_COMPOSE_PROJECT_DIRECTORY="$COMPOSE_PROJECT_DIRECTORY"
export EXTRA_XRAY_CONFIG_DIR="$XRAY_CONFIG_DIR"
export EXTRA_XRAY_CONFIG_FILE="$XRAY_CONFIG_FILE"
export EXTRA_XRAY_COMPOSE_FILE="$XRAY_COMPOSE_FILE"
export EXTRA_XRAY_CERTIFICATE_PATH="$XRAY_CERTIFICATE_PATH"
export EXTRA_XRAY_PRIVATE_KEY_PATH="$XRAY_PRIVATE_KEY_PATH"
export EXTRA_XRAY_CONTAINER_CERTIFICATE_PATH="$XRAY_CONTAINER_CERTIFICATE_PATH"
export EXTRA_XRAY_CONTAINER_PRIVATE_KEY_PATH="$XRAY_CONTAINER_PRIVATE_KEY_PATH"
export EXTRA_LETSENCRYPT_IMAGE="$LETSENCRYPT_IMAGE"
export EXTRA_LETSENCRYPT_STAGING="$LETSENCRYPT_STAGING"
export EXTRA_FORCE_REGENERATE_CERTS="$FORCE_REGENERATE_CERTS"
export EXTRA_XRAY_LOG_LEVEL="$XRAY_LOG_LEVEL"
export EXTRA_XRAY_INBOUND_PORT="$XRAY_INBOUND_PORT"
export EXTRA_XRAY_SERVICE_PORT="$XRAY_SERVICE_PORT"
export EXTRA_XRAY_FLOW="$XRAY_FLOW"
export EXTRA_XRAY_CLIENT_EMAIL="$XRAY_CLIENT_EMAIL"
export EXTRA_XRAY_ALPN_JSON="$XRAY_ALPN_JSON"
export EXTRA_XRAY_IMAGE="$XRAY_IMAGE"
export EXTRA_XRAY_CONTAINER_USER="$XRAY_CONTAINER_USER"
export EXTRA_XRAY_CONTAINER_NAME="$XRAY_CONTAINER_NAME"
export EXTRA_XRAY_FAILURE_LOG_LINES="$XRAY_FAILURE_LOG_LINES"
export EXTRA_DOCKER_COMPOSE_UP="$DOCKER_COMPOSE_UP"
export EXTRA_DOCKER_COMPOSE_DOWN_BEFORE_UP="$DOCKER_COMPOSE_DOWN_BEFORE_UP"
export EXTRA_DOCKER_COMPOSE_REMOVE_ORPHANS="$DOCKER_COMPOSE_REMOVE_ORPHANS"
export EXTRA_XRAY_SERVICE_ROOT="$XRAY_SERVICE_ROOT"
export EXTRA_XRAY_SERVICE_NAME="$XRAY_SERVICE_NAME"
export EXTRA_XRAY_CONFIG_PATH="$XRAY_CONFIG_PATH"
export EXTRA_XRAY_CONTAINER_IMAGE="$XRAY_IMAGE"
export EXTRA_XRAY_CONTAINER_CONFDIR="$XRAY_CONTAINER_CONFDIR"
export EXTRA_XRAY_RESTART_POLICY="$XRAY_RESTART_POLICY"
export EXTRA_XRAY_HOST_PORT="$XRAY_HOST_PORT"
export EXTRA_XRAY_CONTAINER_PORT="$XRAY_CONTAINER_PORT"
export EXTRA_XRAY_COMPOSE_ENVIRONMENT_JSON="$XRAY_COMPOSE_ENVIRONMENT_JSON"
export EXTRA_XRAY_COMPOSE_NETWORKS_JSON="$XRAY_COMPOSE_NETWORKS_JSON"
export EXTRA_XRAY_DEPLOY_WAIT_SECONDS="$XRAY_DEPLOY_WAIT_SECONDS"
export EXTRA_XRAY_DEPLOY_RECOVERY_WAIT_SECONDS="$XRAY_DEPLOY_RECOVERY_WAIT_SECONDS"
export EXTRA_XRAY_DEPLOY_LOG_TAIL_LINES="$XRAY_DEPLOY_LOG_TAIL_LINES"
export EXTRA_XRAY_COMMON_DOCKER_USER="$XRAY_COMMON_DOCKER_USER"
export EXTRA_DOCKER_PREREQS_USER="$DOCKER_PREREQS_USER"
python3 - <<'PY' > "$EXTRA_VARS_FILE"
import json, os, sys


def load_json(key):
    return json.loads(os.environ[key])


payload = {
    "project_root": os.environ["EXTRA_PROJECT_ROOT"],
    "compose_project_directory": os.environ["EXTRA_COMPOSE_PROJECT_DIRECTORY"],
    "xray_config_dir": os.environ["EXTRA_XRAY_CONFIG_DIR"],
    "xray_config_file": os.environ["EXTRA_XRAY_CONFIG_FILE"],
    "xray_compose_file": os.environ["EXTRA_XRAY_COMPOSE_FILE"],
    "certificates_dir": os.environ["EXTRA_CERTIFICATES_DIR"],
    "xray_domain": os.environ["EXTRA_FQDN"],
    "xray_email": os.environ["EXTRA_EMAIL"],
    "xray_uuid": os.environ["EXTRA_UUID"],
    "xray_certificate_path": os.environ["EXTRA_XRAY_CERTIFICATE_PATH"],
    "xray_private_key_path": os.environ["EXTRA_XRAY_PRIVATE_KEY_PATH"],
    "xray_container_certificate_path": os.environ["EXTRA_XRAY_CONTAINER_CERTIFICATE_PATH"],
    "xray_container_private_key_path": os.environ["EXTRA_XRAY_CONTAINER_PRIVATE_KEY_PATH"],
    "letsencrypt_image": os.environ["EXTRA_LETSENCRYPT_IMAGE"],
    "letsencrypt_staging": load_json("EXTRA_LETSENCRYPT_STAGING"),
    "force_regenerate_certs": load_json("EXTRA_FORCE_REGENERATE_CERTS"),
    "xray_log_level": os.environ["EXTRA_XRAY_LOG_LEVEL"],
    "xray_inbound_port": int(os.environ["EXTRA_XRAY_INBOUND_PORT"]),
    "xray_service_port": int(os.environ["EXTRA_XRAY_SERVICE_PORT"]),
    "xray_flow": os.environ["EXTRA_XRAY_FLOW"],
    "xray_client_email": os.environ["EXTRA_XRAY_CLIENT_EMAIL"],
    "xray_alpn": load_json("EXTRA_XRAY_ALPN_JSON"),
    "xray_image": os.environ["EXTRA_XRAY_IMAGE"],
    "xray_container_user": os.environ["EXTRA_XRAY_CONTAINER_USER"],
    "xray_container_name": os.environ["EXTRA_XRAY_CONTAINER_NAME"],
    "xray_failure_log_lines": int(os.environ["EXTRA_XRAY_FAILURE_LOG_LINES"]),
    "docker_compose_up": load_json("EXTRA_DOCKER_COMPOSE_UP"),
    "docker_compose_down_before_up": load_json("EXTRA_DOCKER_COMPOSE_DOWN_BEFORE_UP"),
    "docker_compose_remove_orphans": load_json("EXTRA_DOCKER_COMPOSE_REMOVE_ORPHANS"),
    "xray_service_root": os.environ["EXTRA_XRAY_SERVICE_ROOT"],
    "xray_service_name": os.environ["EXTRA_XRAY_SERVICE_NAME"],
    "xray_config_path": os.environ["EXTRA_XRAY_CONFIG_PATH"],
    "xray_container_image": os.environ["EXTRA_XRAY_CONTAINER_IMAGE"],
    "xray_container_confdir": os.environ["EXTRA_XRAY_CONTAINER_CONFDIR"],
    "xray_restart_policy": os.environ["EXTRA_XRAY_RESTART_POLICY"],
    "xray_host_port": int(os.environ["EXTRA_XRAY_HOST_PORT"]),
    "xray_container_port": int(os.environ["EXTRA_XRAY_CONTAINER_PORT"]),
    "xray_compose_environment": load_json("EXTRA_XRAY_COMPOSE_ENVIRONMENT_JSON"),
    "xray_compose_networks": load_json("EXTRA_XRAY_COMPOSE_NETWORKS_JSON"),
    "xray_deploy_wait_seconds": int(os.environ["EXTRA_XRAY_DEPLOY_WAIT_SECONDS"]),
    "xray_deploy_recovery_wait_seconds": int(os.environ["EXTRA_XRAY_DEPLOY_RECOVERY_WAIT_SECONDS"]),
    "xray_deploy_log_tail_lines": int(os.environ["EXTRA_XRAY_DEPLOY_LOG_TAIL_LINES"]),
    "xray_common_docker_user": os.environ["EXTRA_XRAY_COMMON_DOCKER_USER"],
    "docker_prereqs_user": os.environ["EXTRA_DOCKER_PREREQS_USER"],
}
json.dump(payload, sys.stdout)
PY
unset EXTRA_FQDN EXTRA_EMAIL EXTRA_UUID EXTRA_PROJECT_ROOT \
  EXTRA_CERTIFICATES_DIR EXTRA_COMPOSE_PROJECT_DIRECTORY \
  EXTRA_XRAY_CONFIG_DIR EXTRA_XRAY_CONFIG_FILE \
  EXTRA_XRAY_COMPOSE_FILE EXTRA_XRAY_CERTIFICATE_PATH \
  EXTRA_XRAY_PRIVATE_KEY_PATH EXTRA_XRAY_CONTAINER_CERTIFICATE_PATH \
  EXTRA_XRAY_CONTAINER_PRIVATE_KEY_PATH EXTRA_LETSENCRYPT_IMAGE \
  EXTRA_LETSENCRYPT_STAGING EXTRA_FORCE_REGENERATE_CERTS \
  EXTRA_XRAY_LOG_LEVEL EXTRA_XRAY_INBOUND_PORT \
  EXTRA_XRAY_SERVICE_PORT EXTRA_XRAY_FLOW EXTRA_XRAY_CLIENT_EMAIL \
  EXTRA_XRAY_ALPN_JSON EXTRA_XRAY_IMAGE EXTRA_XRAY_CONTAINER_USER \
  EXTRA_XRAY_CONTAINER_NAME EXTRA_XRAY_FAILURE_LOG_LINES \
  EXTRA_DOCKER_COMPOSE_UP EXTRA_DOCKER_COMPOSE_DOWN_BEFORE_UP \
  EXTRA_DOCKER_COMPOSE_REMOVE_ORPHANS EXTRA_XRAY_SERVICE_ROOT \
  EXTRA_XRAY_SERVICE_NAME EXTRA_XRAY_CONFIG_PATH \
  EXTRA_XRAY_CONTAINER_IMAGE EXTRA_XRAY_CONTAINER_CONFDIR \
  EXTRA_XRAY_RESTART_POLICY EXTRA_XRAY_HOST_PORT \
  EXTRA_XRAY_CONTAINER_PORT EXTRA_XRAY_COMPOSE_ENVIRONMENT_JSON \
  EXTRA_XRAY_COMPOSE_NETWORKS_JSON EXTRA_XRAY_DEPLOY_WAIT_SECONDS \
  EXTRA_XRAY_DEPLOY_RECOVERY_WAIT_SECONDS \
  EXTRA_XRAY_DEPLOY_LOG_TAIL_LINES EXTRA_XRAY_COMMON_DOCKER_USER \
  EXTRA_DOCKER_PREREQS_USER

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
