# lightsail-proxy

🚀 Deploy a ready-to-use proxy host on AWS Lightsail with a single script.

This project provisions and maintains a Lightsail instance, associates a static IP, uploads your SSH key, and opens the required ports so you can jump straight into configuring your proxy stack.

## Prerequisites ✅

- A Namecheap domain with Dynamic DNS enabled and at least one A record created for the subdomain you plan to use.
- Terraform 1.6.6 (matches the automated checks), AWS credentials with Lightsail permissions, and the AWS CLI profile referenced in your variables (`lightsail-proxy/config.tf:1`).
- SSH key pair: the public key will be imported into Lightsail and the private key will be used for SSH/Mosh connections (`lightsail-proxy/variables.tf:38`).
- Optional but handy: `mosh` installed locally to use the generated command in the outputs.
- Optional caching boost: export `TF_PLUGIN_CACHE_DIR` to reuse Terraform provider downloads locally (the CI workflow stores plugins the same way for faster validation).

## Configuration Files 🛠️

### Variables and defaults

- `variables.tf` lists every input the configuration expects, including region maps, Lightsail bundle settings, SSH paths, and secrets such as the Namecheap Dynamic DNS password.
- `defaults.tfvars` provides a starting point; make a copy per deployment (e.g., `expresso.tfvars`) and adjust:
  - `selected_country` / `selected_zone` choose the AWS region and AZ (`lightsail-proxy/variables.tf:11` and `:25`).
  - `instance_customizable_name` becomes part of the instance name.
  - `ssh_public_key_path` / `ssh_private_key_path` point at your key pair.
  - Domain-related settings feed directly into the user data template so the VM can update DNS and configure certificates.
  - `proxy_solution` selects which automation stack boots on the instance (`trojan-go` or `less-vision`).
  - `proxy_contact_email` stays optional for Trojan-Go but is required when `proxy_solution = "less-vision"` so Let’s Encrypt can send certificate notices.

### Choosing a proxy solution

| Capability / Variable                | `trojan-go`                                                                 | `less-vision`                                                                                               |
|--------------------------------------|------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `proxy_solution`                     | Set to `"trojan-go"` (default).                                             | Set to `"less-vision"`.                                                                                    |
| Required contact email               | Optional `proxy_contact_email`; certificates are managed via built-in scripts.| Mandatory `proxy_contact_email` for ACME/Let’s Encrypt registration and expiry notices.                     |
| Certificates                         | Self-manages via the Trojan-Go automation.                                  | ACME certificates issued on first boot; reruns on each replacement host.                                   |
| Post-deploy services                 | Trojan-Go daemon + Nginx reverse proxy; exposes TCP/UDP 443 and 8990.        | less-vision container stack (Docker Compose) bootstrapped in `/opt/lightsail-proxy/less-vision`.           |
| Workspace tfvars additions           | Provide a UUID via `proxy_server_uuid`; no extra toggles required.           | Provide the same `proxy_server_uuid` plus a valid `proxy_contact_email` and ensure DNS points at the host. |

Each workspace-specific tfvars file only needs to override the variables that differ from `defaults.tfvars`. For example:

After `terraform apply`, the Trojan-Go variant publishes TLS and proxy endpoints immediately; verify with `sudo systemctl status trojan-go` and expect TCP/UDP 443 plus TCP 8990 to respond externally. The less-vision deployment launches a Docker Compose application that serves the dashboard and proxy service once certificates issue—check `sudo docker compose ps` under `/opt/lightsail-proxy/less-vision` for healthy containers.

```hcl
# expresso.tfvars
selected_country        = "japan"
selected_zone           = "b"
instance_customizable_name = "expresso"
domain_name             = "example.com"
subdomain_name          = "jp-proxy"
namecheap_ddns_password = "<generated-token>"
proxy_server_uuid       = "00000000-0000-0000-0000-000000000000"
proxy_solution          = "trojan-go"

# expresso.less-vision.tfvars
selected_country        = "japan"
selected_zone           = "b"
instance_customizable_name = "expresso-lv"
domain_name             = "example.com"
subdomain_name          = "jp-lv"
namecheap_ddns_password = "<generated-token>"
proxy_server_uuid       = "11111111-1111-1111-1111-111111111111"
proxy_solution          = "less-vision"
proxy_contact_email     = "admin@example.com"
```

Feel free to create additional files (e.g., `latte.tfvars`) to represent unique environments—just ensure each includes the new `proxy_solution` flag so Terraform can select the correct bootstrap logic.

### Proxy automation assets

- `scripts/trojan-go/` contains the bootstrap shell wrapper and Ansible playbook that previously lived in `setup_env.yaml`. The script downloads the playbook, pipes Terraform-provided variables into JSON, and executes everything locally with consistent logging.
- `scripts/less-vision/` mirrors that structure for the [less-vision](https://github.com/Jeonkwan/less-vision) project. Its bootstrap script clones the upstream repository into `/opt/lightsail-proxy/less-vision`, builds the required `--extra-vars`, and invokes the bundled playbook without touching Trojan-Go resources.

### Workspaces & state

State is kept per workspace inside `terraform.tfstate.d`, so you can run several independent proxy deployments (e.g., `expresso`, `grande`) without collisions.

## How the Terraform stack works 🧩

1. **Provider configuration**  
   `aws` is configured with your chosen profile and shared config/credentials (`lightsail-proxy/config.tf:1`). Region selection comes from the `regions` map keyed by `selected_country`.

2. **Naming strategy & blue/green refresh**  
   Local `instance_name` stitches together the prefix, country, zone, and `instance_customizable_name` (`lightsail-proxy/lightsail.tf:1`). The Lightsail resource then appends a timestamp generated from `formatdate("YYYYMMDDhhmmss", timestamp())` (`lightsail-proxy/lightsail.tf:21`):

   ```hcl
   name = "${local.instance_name}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
   ```

   Terraform computes a new timestamp each time the plan runs, so the `name` field changes and forces a replace of the Lightsail instance. The replacement chain does **not** affect the static IP because `aws_lightsail_static_ip.instance_ip` (`lightsail-proxy/lightsail.tf:9`) and `aws_lightsail_static_ip_attachment.lightsail_instance_ip_attachment` (`lightsail-proxy/lightsail.tf:4`) keep the same identifiers. During `terraform apply` Terraform churns the instance while leaving the static IP mapped, which gives you a blue/green-style refresh:
   - The OS boots from scratch each run, reapplying `setup_ubuntu.sh.tftpl`.
   - TLS certificates and proxy services are renewed automatically because the user-data script reenrolls everything on first boot.
   - Existing clients keep working once the new instance finishes provisioning, since DNS and IP remain unchanged.

3. **Lightsail resources** (`lightsail-proxy/lightsail.tf:4`)
   - `aws_lightsail_static_ip` reserves an address and `aws_lightsail_static_ip_attachment` attaches it to the VM.
   - `aws_lightsail_key_pair` imports your SSH public key for console access.
  - `aws_lightsail_instance` provisions the Ubuntu host and injects cloud-init user data from `setup_ubuntu.sh.tftpl`. The template now wires domain, subdomain, Namecheap token, the shared proxy server UUID, `proxy_solution`, and (when required) `proxy_contact_email` into the script. `setup_ubuntu.sh.tftpl` installs common prerequisites once and then downloads the matching solution bootstrap (`scripts/trojan-go/setup.sh` or `scripts/less-vision/setup.sh`) before running its Ansible playbook.
   - `aws_lightsail_instance_public_ports` opens SSH (22), HTTP (80), HTTPS (443), UDP/TCP proxy ports (8990), and a UDP range used by Mosh (60000-60010).

4. **Outputs** (`lightsail-proxy/output.tf:1`)
   Handy post-deploy commands are rendered for you:
   - `public_ip_address`, `hostname`, and `ssh_key_pair_name`
   - `ssh-connect`/`mosh-connect` strings so you can copy/paste straight into a terminal

## `tf_action.sh` Helper Script 🤖

Before running any helper command, double-check that the tfvars file you plan to use sets `proxy_solution` to the intended value. The script streamlines Terraform workflows with safety checks:

- **Workspace validation** – Ensures the active workspace matches the `.tfvars` file you target.
- **Init wrapper** – Keeps providers pinned via `.terraform.lock.hcl` by default and only upgrades when you export `TF_UPGRADE=true`.
- **Subcommands**
  - `plan <workspace>`: runs `terraform plan -var-file=<workspace>.tfvars`
  - `deploy <workspace> <apply|destroy>`: interactive apply or destroy
  - `deploy-auto <workspace> <apply|destroy>`: same as above with `-auto-approve`

Example session:

```bash
# Preview changes using the workspace + tfvars name convention
./tf_action.sh plan expresso

# Reconcile infrastructure without manual prompts
./tf_action.sh deploy-auto expresso apply
```

## Typical Workflow ☕

1. **Copy defaults**: `cp defaults.tfvars expresso.tfvars` and tailor to your region, domain, passwords, and SSH paths.
2. **Initialize & plan**: `./tf_action.sh plan expresso`
3. **Deploy**: `./tf_action.sh deploy expresso apply` (or `deploy-auto` when running unattended).
4. **Connect**: Grab the `ssh-connect` command from Terraform outputs and log in.
5. **Cycle the host**: Re-run `deploy-auto expresso apply` whenever you need a fresh instance; the static IP and DNS records remain intact.

## Continuous Integration 🔄

- Every pull request runs the **Terraform Validate** GitHub Actions workflow, which performs `terraform init -backend=false` followed by `terraform validate` using Terraform 1.6.6.
- To match CI locally, run the same commands from the repository root and consider exporting `TF_PLUGIN_CACHE_DIR` so Terraform can reuse provider downloads between runs.

## Troubleshooting 🧯

- **Provider downloads**: The `.terraform.lock.hcl` file pins `hashicorp/aws` v6.16.0. If you intentionally want to upgrade, export `TF_UPGRADE=true` before running any `tf_action.sh` command.
- **Workspace mismatch**: The script will warn you if the currently selected workspace differs from the tfvars you requested—fix by running `terraform workspace select <name>` or by creating the workspace on first run.
- **SSH paths**: Make sure the private key path in your tfvars points to the matching private key (`.pub` is trimmed automatically when building output commands).
- **Trojan-Go certificates**: If the Trojan-Go stack redeploys without a certificate, re-run the workspace with `proxy_solution = "trojan-go"` and confirm port 80 is reachable from the public internet so the bundled ACME script can validate ownership.
- **less-vision certificate issuance**: Ensure `proxy_contact_email` is populated and the `domain_name`/`subdomain_name` A records resolve to the Lightsail static IP before boot. After deployment, you can verify renewal timers with `sudo systemctl status certbot.timer`.
- **less-vision Docker Compose services**: Log in and run `cd /opt/lightsail-proxy/less-vision && sudo docker compose ps` to check container status. Use `sudo docker compose logs <service>` if any container repeatedly restarts.

Happy proxying! 🛡️💻
