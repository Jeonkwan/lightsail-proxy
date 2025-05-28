#!/usr/bin/env bash

set_workspace() {
    local ws_name=$1
    terraform workspace select -or-create=true $ws_name
    terraform workspace show
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
    [[ $is_ws_correct -eq 0 ]] && { terraform init -upgrade; terraform validate; terraform plan -var-file=${ws_name}.tfvars }
}

tf_deploy() {
    local ws_name=$1
    local action=$2
    validate_ws_and_tfvar_file $ws_name
    is_ws_correct=$?
    [[ ! -n "$action" ]] && { echo "Missing Action Argument apply or destroy"; return 1;}
    [[ $is_ws_correct -eq 0 ]] && { terraform init -upgrade; terraform validate; terraform $action -var-file=${ws_name}.tfvars; }
}

tf_deploy_auto() {
    local ws_name=$1
    local action=$2
    validate_ws_and_tfvar_file $ws_name
    is_ws_correct=$?
    [[ ! -n "$action" ]] && { echo "Missing Action Argument apply or destroy"; return 1;}
    [[ $is_ws_correct -eq 0 ]] && { terraform init -upgrade; terraform validate; terraform $action -var-file=${ws_name}.tfvars -auto-approve; }
}