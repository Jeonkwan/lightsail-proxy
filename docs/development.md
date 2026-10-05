# Development environment

For selectable native/Docker deployment, switching and the spare-validation plan, see [selectable runtime](selectable-xray-runtime.md).

Use a Linux workstation or CI runner with Bash, Git, curl, OpenSSH client and
Python 3.12 (including venv/pip). Install tools on the control host, not on the
512 MB proxy VM. macOS can be used with equivalent tools; the documented checks
have been validated on Linux.

## Tools and setup

| Tool | Version / purpose |
| --- | --- |
| Python | 3.12; local development and Ansible control host |
| GitHub CLI (`gh`) | Authenticated CLI for repository access and Actions; tested 2.46.0 |
| Terraform | 1.6.6; infrastructure repo CI version |
| Ansible core | 2.16.19; tested with Python 3.12 |
| Docker Engine / Compose | Optional on workstation; credential generation requires Docker; not required on native deployed hosts |
| AWS CLI v2 | Optional for direct AWS inspection; unnecessary for local static checks |
| sing-box | Optional 1.11.4 for supplied legacy client configurations and authenticated proxy validation |

Install Git, curl, OpenSSH, Python 3.12 and its venv support through your platform's
package manager. Install `gh` using the official GitHub CLI instructions and
Terraform 1.6.6 from HashiCorp's official release (verify its checksum). Add the
executables to PATH. These tools are prerequisites; cloning does not install them.

Create a dedicated virtual environment outside tracked files:

```bash
python3.12 -m venv "$HOME/.venvs/proxy-development"
source "$HOME/.venvs/proxy-development/bin/activate"
python -m pip install 'ansible-core==2.16.19'
python --version
ansible --version
terraform version
gh --version
```

The selectable playbook uses `ansible.builtin` modules for native systemd or Docker Compose deployment. Native remains the default. No extra Ansible Galaxy collection or Python Docker SDK is
required for this deployment. Python's standard library suffices for the
bootstrap tests and diagnostic script. Do not install unrelated packages by default.

For the previously prepared workspace, `source /workspace/proxy/activate.sh`
selects its installed tools and writable Ansible/cache paths. That helper is
workspace-specific and is not part of a fresh repository clone.

## Repository relationship

Clone `Jeonkwan/lightsail-proxy` (Terraform and OS bootstrap) and
`Jeonkwan/less-vision-reality` (Ansible and Xray) as sibling directories. Changes
currently use `feature/selectable-xray-runtime` in both repositories. Check remote branch
availability before checkout; do not assume it remains the development branch
forever. `Jeonkwan/gcp-proxy` is a separate optional infrastructure project;
GCP credentials and tooling are not prerequisites for this Lightsail work.

```bash
mkdir -p proxy-workspace
cd proxy-workspace
gh repo clone Jeonkwan/lightsail-proxy
gh repo clone Jeonkwan/less-vision-reality
git -C lightsail-proxy switch feature/selectable-xray-runtime
git -C less-vision-reality switch feature/selectable-xray-runtime
```

## Authentication and configuration

Local syntax/bootstrap checks below require no AWS account credentials, SSH key,
proxy secrets or access to live VMs. Package/provider downloads need HTTPS access
to GitHub, PyPI and HashiCorp; runtime image pulls additionally need GHCR and
Docker's registries. Preserve any environment-provided proxy and CA settings.

Use `gh auth status` to check GitHub access. If authentication is absent, use your
approved GitHub connection or `gh auth login` on an interactive workstation.
Repository access and workflow dispatch require corresponding repository/Actions
permissions. GitHub authentication does not provide local AWS or SSH credentials.

Prefer GitHub Actions for deployment: credentials already stored in GitHub
repository/environments stay there. Check workflow definitions for the exact
secret names and selected environment before dispatch. Do not extract or print
secret values, commit private keys, client configuration, tfvars secrets or state,
or upload unfiltered deployment logs/credential summaries.

Direct Terraform operations additionally require the configured AWS profile,
S3 backend access, matching workspace/tfvars and SSH public key. Direct Ansible
execution requires the target inventory, SSH private key/user/port and sudo
access. Neither is required to begin development.

## Lightsail checks (from repository root)

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
python3 scripts/tests/test_proxy_bootstrap.py
python3 scripts/tests/test_native_infrastructure.py
git diff --check
```

Initialization downloads the locked providers; `-backend=false` avoids accessing
remote state. The bootstrap test renders the actual Terraform template and mocks
host commands in temporary directories. It tests first boot, resume and failed
reboot protection without rebooting the workstation or contacting a VM.

The deployment workflow uses `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`SSH_PUBLIC_KEY`, and backend variables `TF_BACKEND_BUCKET`, `TF_BACKEND_KEY`,
`TF_BACKEND_REGION`. Review `.github/workflows/terraform-deploy.yml` for mode-
specific proxy/DNS secrets and inputs. Use `basic-vm` for the two-stage deployment;
bootstrap readiness requires `/var/lib/proxy-bootstrap/complete` and active
`kho=off`, before running the separate proxy deployment.

Terraform plans may replace timestamp-named instances. Never treat `apply` as a
read-only check. Do not run apply/destroy on a shared workspace as part of setup.
Read [disposable VM strategy](disposable-proxy-vms.md) and
[Actions deployment](github-actions-deployment.md) before live operations.

See [Americano/Latte validation and cleanup](selectable-runtime-validation.md) for the task scope and evidence.
