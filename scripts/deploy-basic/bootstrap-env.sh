#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

TF_WORKSPACE="${TF_WORKSPACE:-default}"
# Trim whitespace
TF_WORKSPACE="$(echo -e "${TF_WORKSPACE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

echo "Bootstrapping environment for workspace '${TF_WORKSPACE}'..."

# Run inline Python script to parse tfvars and write credentials / SSH keys
python3 - <<'PY'
import os
import re
import subprocess
import json
import uuid

workspace = os.environ.get("TF_WORKSPACE", "default")
tfvars_file = f"{workspace}.tfvars"
tfvars_exists = os.path.exists(tfvars_file)

if not tfvars_exists:
    print(f"Workspace config file '{tfvars_file}' not found. Relying entirely on environment variables.")

content = ""
if tfvars_exists:
    print(f"Reading configuration from {tfvars_file}...")
    with open(tfvars_file, "r", encoding="utf-8") as f:
        content = f.read()

def get_var(name, default):
    # Regex to match variable assignment in HCL
    match = re.search(rf'^\s*{name}\s*=\s*"([^"]+)"', content, re.MULTILINE)
    return match.group(1) if match else default

def set_github_env(name, val):
    github_env = os.environ.get("GITHUB_ENV")
    if github_env:
        # Use heredoc to handle multiline values and special characters safely
        delimiter = f"EOF_{uuid.uuid4().hex}"
        with open(github_env, "a", encoding="utf-8") as f:
            f.write(f"{name}<<{delimiter}\n{val}\n{delimiter}\n")
        print(f"Exported to GITHUB_ENV: {name}")

# Dynamic lookup of workspace-prefixed environment/repository variables
vars_context_str = os.environ.get("VARS_CONTEXT", "{}")
try:
    vars_dict = json.loads(vars_context_str)
except Exception as e:
    print(f"Error parsing VARS_CONTEXT: {e}")
    vars_dict = {}

all_vars = {**vars_dict}
for k, v in os.environ.items():
    all_vars[k] = v

workspace_prefix = workspace.upper().replace("-", "_").replace(".", "_") + "_"
print(f"Checking for workspace-specific variables with prefix '{workspace_prefix}'...")

for key, value in all_vars.items():
    if key.upper().startswith(workspace_prefix):
        var_suffix = key[len(workspace_prefix):].lower()
        tf_var_name = f"TF_VAR_{var_suffix}"
        print(f"Found workspace variable: {key} -> setting {tf_var_name}")
        os.environ[tf_var_name] = value
        set_github_env(tf_var_name, value)

# Check and prioritize path variables from environment (TF_VAR_...) or HCL parsing
aws_cred_path = os.environ.get("TF_VAR_aws_cred_file_path", get_var("aws_cred_file_path", "~/.aws/credentials"))
aws_conf_path = os.environ.get("TF_VAR_aws_conf_file_path", get_var("aws_conf_file_path", "~/.aws/config"))
ssh_pub_path = os.environ.get("TF_VAR_ssh_public_key_path", get_var("ssh_public_key_path", "~/.ssh/jeonkwan-mbp.pub"))

def expand_path(p):
    return os.path.expanduser(p)

# Write AWS Credentials
aws_key = os.environ.get("AWS_ACCESS_KEY_ID", "")
aws_secret = os.environ.get("AWS_SECRET_ACCESS_KEY", "")
if aws_key and aws_secret:
    aws_cred_real = expand_path(aws_cred_path)
    os.makedirs(os.path.dirname(aws_cred_real), exist_ok=True)
    with open(aws_cred_real, "w", encoding="utf-8") as f:
        f.write(f"[default]\naws_access_key_id = {aws_key}\naws_secret_access_key = {aws_secret}\n")
    os.chmod(aws_cred_real, 0o600)
    print(f"Wrote AWS credentials to {aws_cred_real}")
else:
    print("Warning: AWS credentials environment variables not found.")

# Write AWS Config
aws_region = os.environ.get("AWS_DEFAULT_REGION", "ap-southeast-1")
aws_conf_real = expand_path(aws_conf_path)
os.makedirs(os.path.dirname(aws_conf_real), exist_ok=True)
with open(aws_conf_real, "w", encoding="utf-8") as f:
    f.write(f"[default]\nregion = {aws_region}\n")
print(f"Wrote AWS config to {aws_conf_real}")

# Write SSH Public Key
ssh_pub_content = os.environ.get("SSH_PUBLIC_KEY", "")
if ssh_pub_content:
    ssh_pub_real = expand_path(ssh_pub_path)
    os.makedirs(os.path.dirname(ssh_pub_real), exist_ok=True)
    with open(ssh_pub_real, "w", encoding="utf-8") as f:
        f.write(ssh_pub_content.strip() + "\n")
    os.chmod(ssh_pub_real, 0o600)
    print(f"Wrote SSH public key to {ssh_pub_real}")

    # Fallback to literal tilde path inside workspace for safety
    if ssh_pub_path.startswith("~"):
        literal_pub = "." + ssh_pub_path[1:]
        os.makedirs(os.path.dirname(literal_pub), exist_ok=True)
        with open(literal_pub, "w", encoding="utf-8") as f:
            f.write(ssh_pub_content.strip() + "\n")
        os.chmod(literal_pub, 0o600)
        print(f"Wrote SSH public key to literal path {literal_pub}")
else:
    print("Warning: SSH_PUBLIC_KEY environment variable not found.")

PY

# Auto-create backend S3 Bucket if specified and doesn't exist
if [[ -n "${TF_BACKEND_BUCKET:-}" ]]; then
  BACKEND_REGION="${TF_BACKEND_REGION:-ap-southeast-1}"
  echo "Checking S3 bucket '${TF_BACKEND_BUCKET}' in region '${BACKEND_REGION}'..."
  
  if ! aws s3api head-bucket --bucket "${TF_BACKEND_BUCKET}" 2>/dev/null; then
    echo "Bucket '${TF_BACKEND_BUCKET}' does not exist. Creating it..."
    
    # Check if the region is us-east-1 (which is the default region that doesn't accept LocationConstraint)
    if [[ "${BACKEND_REGION}" == "us-east-1" ]]; then
      aws s3api create-bucket \
        --bucket "${TF_BACKEND_BUCKET}" \
        --region "${BACKEND_REGION}"
    else
      aws s3api create-bucket \
        --bucket "${TF_BACKEND_BUCKET}" \
        --region "${BACKEND_REGION}" \
        --create-bucket-configuration LocationConstraint="${BACKEND_REGION}"
    fi
    
    # Enable versioning for state files safety
    echo "Enabling versioning on bucket '${TF_BACKEND_BUCKET}'..."
    aws s3api put-bucket-versioning \
      --bucket "${TF_BACKEND_BUCKET}" \
      --versioning-configuration Status=Enabled
      
    # Enable AES256 server-side encryption by default
    echo "Enabling default server-side encryption on bucket '${TF_BACKEND_BUCKET}'..."
    aws s3api put-bucket-encryption \
      --bucket "${TF_BACKEND_BUCKET}" \
      --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
      
    echo "Successfully created S3 bucket '${TF_BACKEND_BUCKET}'."
  else
    echo "S3 bucket '${TF_BACKEND_BUCKET}' already exists."
  fi
fi

ENV_FILE="${ROOT_DIR}/.env.deploy"
cat > "${ENV_FILE}" <<EOF_ENV
export AWS_DEFAULT_REGION="${TF_BACKEND_REGION:-ap-southeast-1}"
EOF_ENV

echo "Bootstrap completed successfully."
