#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

TF_ACTION="${TF_ACTION:-apply}"
TF_ROOT="${TF_ROOT:-${ROOT_DIR}}"
TF_PLAN_DIR="${TF_PLAN_DIR:-${ROOT_DIR}/artifacts/terraform}"
TF_PLAN_FILE="${TF_PLAN_FILE:-${TF_PLAN_DIR}/terraform.tfplan}"

if [[ -n "${TF_WORKSPACE:-}" ]]; then
  TF_WORKSPACE="$(echo -e "${TF_WORKSPACE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  export TF_WORKSPACE
fi

WORKSPACE_NAME="${TF_WORKSPACE:-default}"

if [[ "${TF_ACTION}" == "plan" ]]; then
  echo "TF_ACTION=plan, skipping terraform apply"
  exit 0
fi

if [[ ! -f "${TF_PLAN_FILE}" ]]; then
  echo "Terraform plan file ${TF_PLAN_FILE} not found. Run terraform-plan.sh first." >&2
  exit 1
fi

pushd "${TF_ROOT}" >/dev/null

VAR_ARGS=()
if [[ -n "${TF_VAR_namecheap_ddns_password:-}" ]]; then
  VAR_ARGS+=("-var=namecheap_ddns_password=${TF_VAR_namecheap_ddns_password}")
fi
if [[ -n "${TF_VAR_proxy_server_uuid:-}" ]]; then
  VAR_ARGS+=("-var=proxy_server_uuid=${TF_VAR_proxy_server_uuid}")
fi
if [[ -n "${TF_VAR_less_vision_reality_private_key:-}" ]]; then
  VAR_ARGS+=("-var=less_vision_reality_private_key=${TF_VAR_less_vision_reality_private_key}")
fi
if [[ -n "${TF_VAR_less_vision_reality_public_key:-}" ]]; then
  VAR_ARGS+=("-var=less_vision_reality_public_key=${TF_VAR_less_vision_reality_public_key}")
fi
if [[ -n "${TF_VAR_selected_country:-}" ]]; then
  VAR_ARGS+=("-var=selected_country=${TF_VAR_selected_country}")
fi
if [[ -n "${TF_VAR_selected_zone:-}" ]]; then
  VAR_ARGS+=("-var=selected_zone=${TF_VAR_selected_zone}")
fi
if [[ -n "${TF_VAR_instance_customizable_name:-}" ]]; then
  VAR_ARGS+=("-var=instance_customizable_name=${TF_VAR_instance_customizable_name}")
fi
if [[ -n "${TF_VAR_domain_name:-}" ]]; then
  VAR_ARGS+=("-var=domain_name=${TF_VAR_domain_name}")
fi
if [[ -n "${TF_VAR_subdomain_name:-}" ]]; then
  VAR_ARGS+=("-var=subdomain_name=${TF_VAR_subdomain_name}")
fi
if [[ -n "${TF_VAR_proxy_solution:-}" ]]; then
  VAR_ARGS+=("-var=proxy_solution=${TF_VAR_proxy_solution}")
fi
if [[ -n "${TF_VAR_proxy_contact_email:-}" ]]; then
  VAR_ARGS+=("-var=proxy_contact_email=${TF_VAR_proxy_contact_email}")
fi
if [[ -n "${TF_VAR_playbook_branch:-}" ]]; then
  VAR_ARGS+=("-var=playbook_branch=${TF_VAR_playbook_branch}")
fi

if [[ "${TF_ACTION}" == "destroy" ]]; then
  terraform destroy -var-file="${WORKSPACE_NAME}.tfvars" "${VAR_ARGS[@]}" -auto-approve
elif [[ "${TF_ACTION}" == "test-full-cycle" ]]; then
  echo "Starting full cycle test: Apply..."
  terraform apply -input=false "${TF_PLAN_FILE}"
  
  echo "Full cycle test: Apply complete. Starting Destroy..."
  terraform destroy -var-file="${WORKSPACE_NAME}.tfvars" "${VAR_ARGS[@]}" -auto-approve
else
  terraform apply -input=false "${TF_PLAN_FILE}"
fi

popd >/dev/null

"${SCRIPT_DIR}/post-apply.sh"
