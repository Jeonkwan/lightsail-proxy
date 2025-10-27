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
   - `aws_lightsail_instance` provisions the Ubuntu host and injects cloud-init user data from `setup_ubuntu.sh.tftpl`. The template receives domain, subdomain, Namecheap token, and Trojan-Go password via `templatefile`.
   - `aws_lightsail_instance_public_ports` opens SSH (22), HTTP (80), HTTPS (443), UDP/TCP proxy ports (8990), and a UDP range used by Mosh (60000-60010).

4. **Outputs** (`lightsail-proxy/output.tf:1`)
   Handy post-deploy commands are rendered for you:
   - `public_ip_address`, `hostname`, and `ssh_key_pair_name`
   - `ssh-connect`/`mosh-connect` strings so you can copy/paste straight into a terminal

## `tf_action.sh` Helper Script 🤖

The script streamlines Terraform workflows with safety checks:

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

Happy proxying! 🛡️💻
