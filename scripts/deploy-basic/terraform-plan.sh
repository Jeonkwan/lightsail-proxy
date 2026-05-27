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

VAR_FILE_ARGS=()
if [[ -f "${WORKSPACE_NAME}.tfvars" ]]; then
  VAR_FILE_ARGS+=("-var-file=${WORKSPACE_NAME}.tfvars")
fi

# Auto-detect region mismatch and clean up resources in the old region first
OLD_STATE_INFO=$(terraform state pull 2>/dev/null | python3 -c '
import sys, json
try:
    state = json.load(sys.stdin)
    country = None
    zone_suffix = "a"
    region = None
    for res in state.get("resources", []):
        if res.get("type") == "aws_lightsail_instance":
            for inst in res.get("instances", []):
                az = inst.get("attributes", {}).get("availability_zone")
                if az:
                    region = az[:-1]
                    zone_suffix = az[-1]
                    break
            if region:
                break
    if not region:
        for res in state.get("resources", []):
            if res.get("type") in ["aws_lightsail_static_ip", "aws_lightsail_static_ip_attachment"]:
                for inst in res.get("instances", []):
                    reg = inst.get("attributes", {}).get("region")
                    if reg:
                        region = reg
                        break
                if region:
                    break
    if region:
        if region == "ap-northeast-1": country = "japan"
        elif region == "ap-northeast-2": country = "korea"
        elif region == "ap-south-1": country = "india"
        elif region == "ap-east-1": country = "hong kong"
        elif region == "ap-southeast-3": country = "indonesia"
        else: country = "singapore"
        print(f"{country} {zone_suffix} {region}")
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
' || echo "")

if [[ -n "${OLD_STATE_INFO}" ]]; then
  read -r OLD_COUNTRY OLD_ZONE OLD_REGION <<< "${OLD_STATE_INFO}"
  
  TARGET_COUNTRY="${TF_VAR_selected_country:-singapore}"
  case "${TARGET_COUNTRY}" in
    singapore) TARGET_REGION="ap-southeast-1" ;;
    japan)     TARGET_REGION="ap-northeast-1" ;;
    korea)     TARGET_REGION="ap-northeast-2" ;;
    india)     TARGET_REGION="ap-south-1" ;;
    "hong kong") TARGET_REGION="ap-east-1" ;;
    indonesia) TARGET_REGION="ap-southeast-3" ;;
    *)         TARGET_REGION="ap-southeast-1" ;;
  esac
  
  if [[ "${OLD_REGION}" != "${TARGET_REGION}" && "${TF_ACTION}" != "destroy" ]]; then
    echo "=========================================================="
    echo "WARNING: Workspace '${WORKSPACE_NAME}' is currently deployed in ${OLD_COUNTRY} (${OLD_REGION}), zone ${OLD_ZONE}."
    echo "Target region is ${TARGET_COUNTRY} (${TARGET_REGION})."
    echo "To change regions, we must destroy the existing resources in ${OLD_REGION} first."
    echo "Automatically destroying existing resources in ${OLD_REGION}..."
    echo "=========================================================="
    
    DESTROY_VAR_ARGS=("${VAR_ARGS[@]}")
    DESTROY_VAR_ARGS+=("-var=selected_country=${OLD_COUNTRY}" "-var=selected_zone=${OLD_ZONE}")
    
    ORIGINAL_AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}"
    export AWS_DEFAULT_REGION="${OLD_REGION}"
    
    echo "Running terraform destroy in ${OLD_REGION}..."
    terraform destroy "${VAR_FILE_ARGS[@]}" "${DESTROY_VAR_ARGS[@]}" -auto-approve
    
    if [[ -n "${ORIGINAL_AWS_DEFAULT_REGION}" ]]; then
      export AWS_DEFAULT_REGION="${ORIGINAL_AWS_DEFAULT_REGION}"
    else
      unset AWS_DEFAULT_REGION
    fi
    
    echo "=========================================================="
    echo "Successfully destroyed old resources. Proceeding with new deployment in ${TARGET_REGION}."
    echo "=========================================================="
  fi
fi

PLAN_FLAGS=("-out=${TF_PLAN_FILE}" "-input=false")
if [[ "${TF_ACTION}" == "destroy" ]]; then
  PLAN_FLAGS+=("-destroy")
fi

terraform plan "${VAR_FILE_ARGS[@]}" "${VAR_ARGS[@]}" "${PLAN_FLAGS[@]}"


terraform show -json "${TF_PLAN_FILE}" > "${TF_PLAN_JSON}"

popd >/dev/null

echo "Terraform plan stored at ${TF_PLAN_FILE}"
echo "Terraform plan JSON stored at ${TF_PLAN_JSON}"
