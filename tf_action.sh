#!/usr/bin/env bash

set_workspace() {
    local ws_name=$1
    terraform workspace select -or-create=true $ws_name
    terraform workspace show
}

terraform_init() {
    local init_args=()
    # Allow opting-in to provider/module upgrades via TF_UPGRADE=1|true.
    if [[ "${TF_UPGRADE}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
        init_args+=("-upgrade")
    fi
    terraform init "${init_args[@]}"
}

validate_ws_and_tfvar_file() {
    local ws_name=$1

    set_workspace $ws_name
    local current_ws_name=$(terraform workspace show)
    echo "Current Workspace [$current_ws_name] and tfvars file [$ws_name]"
    if [[ "$current_ws_name" == "$ws_name" ]]; then
        echo "Match"
        return 0
    else
        echo "Mismatch"
        return 1
    fi
}


tf_plan() {
    local ws_name=$1
    validate_ws_and_tfvar_file $ws_name
    is_ws_correct=$?
    [[ $is_ws_correct -eq 0 ]] && { terraform_init; terraform validate; terraform plan -var-file=${ws_name}.tfvars; }
}

tf_deploy() {
    local ws_name=$1
    local action=$2
    validate_ws_and_tfvar_file $ws_name
    is_ws_correct=$?
    [[ ! -n "$action" ]] && { echo "Missing Action Argument apply or destroy"; return 1;}
    [[ $is_ws_correct -eq 0 ]] && { terraform_init; terraform validate; terraform $action -var-file=${ws_name}.tfvars; }
}

tf_deploy_auto() {
    local ws_name=$1
    local action=$2
    validate_ws_and_tfvar_file $ws_name
    is_ws_correct=$?
    [[ ! -n "$action" ]] && { echo "Missing Action Argument apply or destroy"; return 1;}
    [[ $is_ws_correct -eq 0 ]] && { terraform_init; terraform validate; terraform $action -var-file=${ws_name}.tfvars -auto-approve; }
}

print_usage() {
    cat <<'EOF'
Usage:
  ./tf_action.sh plan <workspace>
  ./tf_action.sh deploy <workspace> <apply|destroy>
  ./tf_action.sh deploy-auto <workspace> <apply|destroy>

Environment:
  TF_UPGRADE=true|1   Include -upgrade during terraform init.
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command=$1
    workspace=$2
    action=$3

    case "$command" in
        plan)
            [[ -z "$workspace" ]] && { echo "Missing workspace argument"; print_usage; exit 1; }
            tf_plan "$workspace"
            ;;
        deploy)
            [[ -z "$workspace" || -z "$action" ]] && { echo "Missing arguments"; print_usage; exit 1; }
            tf_deploy "$workspace" "$action"
            ;;
        deploy-auto)
            [[ -z "$workspace" || -z "$action" ]] && { echo "Missing arguments"; print_usage; exit 1; }
            tf_deploy_auto "$workspace" "$action"
            ;;
        ""|-h|--help|help)
            print_usage
            ;;
        *)
            echo "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
fi
