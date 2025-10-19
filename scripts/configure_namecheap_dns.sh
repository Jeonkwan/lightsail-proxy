#!/usr/bin/env bash
set -euo pipefail

SAMPLE_DOMAIN="example.com"
SAMPLE_SUBDOMAIN="sub1"

[[ -z "${DOMAIN:-}" ]] && { read -r -p "Domain name (e.g.: ${SAMPLE_DOMAIN}): " DOMAIN; }
[[ -z "${SUBDOMAIN:-}" ]] && { read -r -p "Subdomain name (e.g.: ${SAMPLE_SUBDOMAIN}): " SUBDOMAIN; }
[[ -z "${INSTANCE_PUBLIC_IP:-}" ]] && { read -r -p "Instance public IP address: " INSTANCE_PUBLIC_IP; }
[[ -z "${NAMECHEAP_DDNS_PASS:-}" ]] && { read -s -r -p "Namecheap Dynamic DNS Password: " NAMECHEAP_DDNS_PASS; echo; }

response=$(curl -fsS "https://dynamicdns.park-your-domain.com/update?host=${SUBDOMAIN}&domain=${DOMAIN}&password=${NAMECHEAP_DDNS_PASS}&ip=${INSTANCE_PUBLIC_IP}")

err_count=$(sed -n 's:.*<ErrCount>\([^<]*\)</ErrCount>.*:\1:p' <<<"${response}")
fqdn="${SUBDOMAIN}.${DOMAIN}"
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
status="success"
error_message=""

if [[ "${err_count}" != "0" ]]; then
  status="error"
  error_message=$(sed -n 's:.*<Err1>\([^<]*\)</Err1>.*:\1:p' <<<"${response}")
  if [[ -z "${error_message}" ]]; then
    error_message="Namecheap DNS update failed"
  fi
fi

log_file=${NAMECHEAP_DDNS_LOG:-}
if [[ -n "${log_file}" ]]; then
  mkdir -p "$(dirname "${log_file}")"
  {
    echo "Timestamp: ${timestamp}"
    echo "FQDN: ${fqdn}"
    echo "IP Address: ${INSTANCE_PUBLIC_IP}"
    echo "Status: ${status}"
    if [[ "${status}" == "error" ]]; then
      echo "Error: ${error_message}"
    fi
    echo "Raw response:"
    echo "${response}"
  } >"${log_file}"
fi

echo "${status}: ${fqdn} -> ${INSTANCE_PUBLIC_IP}"

if [[ "${status}" != "success" ]]; then
  echo "Namecheap DNS update failed: ${error_message}" >&2
  exit 1
fi

