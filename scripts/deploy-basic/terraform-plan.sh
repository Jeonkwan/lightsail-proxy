#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

TF_WORKSPACE="${TF_WORKSPACE:-default}"
TF_WORKSPACE="$(echo -e "${TF_WORKSPACE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
WORKSPACE_NAME="${TF_WORKSPACE}"
unset TF_WORKSPACE

TF_ACTION="${TF_ACTION:-apply}"
TF_ROOT="${TF_ROOT:-${ROOT_DIR}}"
TF_PLAN_DIR="${TF_PLAN_DIR:-${ROOT_DIR}/artifacts/terraform}"
TF_PLAN_FILE="${TF_PLAN_FILE:-${TF_PLAN_DIR}/terraform.tfplan}"
TF_PLAN_JSON="${TF_PLAN_JSON:-${TF_PLAN_DIR}/plan.json}"

mkdir -p "${TF_PLAN_DIR}"

BACKEND_ARGS=()
if [[ -n "${TF_BACKEND_BUCKET:-}" ]]; then
  BACKEND_ARGS+=("-backend-config=bucket=${TF_BACKEND_BUCKET}")
fi
if [[ -n "${TF_BACKEND_KEY:-}" ]]; then
  BACKEND_ARGS+=("-backend-config=key=${TF_BACKEND_KEY}")
fi
if [[ -n "${TF_BACKEND_REGION:-}" ]]; then
  BACKEND_ARGS+=("-backend-config=region=${TF_BACKEND_REGION}")
fi

pushd "${TF_ROOT}" >/dev/null

terraform init -input=false "${BACKEND_ARGS[@]}"

echo "Selecting or creating workspace '${WORKSPACE_NAME}'..."
terraform workspace select -or-create "${WORKSPACE_NAME}"

# Re-export TF_WORKSPACE for subsequent commands
export TF_WORKSPACE="${WORKSPACE_NAME}"

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
if [[ -n "${TF_VAR_less_vision_reality_short_ids:-}" ]]; then
  VAR_ARGS+=("-var=less_vision_reality_short_ids=${TF_VAR_less_vision_reality_short_ids}")
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

PLAN_FLAGS=("-out=${TF_PLAN_FILE}" "-input=false")
if [[ "${TF_ACTION}" == "destroy" ]]; then
  PLAN_FLAGS+=("-destroy")
fi

VAR_FILE_ARGS=()
if [[ -f "${WORKSPACE_NAME}.tfvars" ]]; then
  VAR_FILE_ARGS+=("-var-file=${WORKSPACE_NAME}.tfvars")
fi

terraform plan "${VAR_FILE_ARGS[@]}" "${VAR_ARGS[@]}" "${PLAN_FLAGS[@]}"

terraform show -json "${TF_PLAN_FILE}" > "${TF_PLAN_JSON}"

popd >/dev/null

echo "Terraform plan stored at ${TF_PLAN_FILE}"
echo "Terraform plan JSON stored at ${TF_PLAN_JSON}"
