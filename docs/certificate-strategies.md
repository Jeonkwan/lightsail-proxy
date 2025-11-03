# Pre-provisioning TLS Certificates for Lightsail Deployments

The Terraform module currently relies on each Lightsail instance to request and renew its own
TLS material during first boot via the solution-specific Ansible playbook. This keeps issuance
simple because the host can satisfy HTTP challenges once the reverse proxy stack is online. If
you need to generate certificates on the machine that runs Terraform and then push them to the
instance at launch time, the following approaches are available.

## 1. Use the Namecheap DNS API with an ACME DNS-01 flow (Recommended)

**How it works**

1. Install an ACME client on the deployment host (e.g., [`acme.sh`](https://github.com/acmesh-official/acme.sh) or Certbot).
2. Call the Namecheap DNS API to create `_acme-challenge` TXT records for the domain while the VM is offline.
3. Complete the DNS-01 validation to receive the certificate bundle locally.
4. Upload the key and certificate to the new instance during provisioning (for example, via the cloud-init template or a post-create Ansible run) and skip the in-guest issuance step.

**Why it can work**

- DNS-01 does not require the Lightsail host to be reachable during validation, so you can finish issuance before Terraform provisions the VM.
- The project already talks to Namecheap's Dynamic DNS endpoint, so storing Namecheap API credentials on the deployer is a reasonable extension.
- Certificates can be versioned or wrapped in secure storage (e.g., SOPS, HashiCorp Vault) before transfer.

**Trade-offs / caveats**

- You must automate TXT record cleanup to avoid stale `_acme-challenge` entries.
- Handling the private key locally changes the threat model—the deployment workstation now needs hardware or software protections that the ephemeral Lightsail host previously provided by design.
- DNS propagation can take a few minutes, so Terraform should wait or poll before launching the instance.

## 2. Ask Terraform to issue certificates via the `acme` provider and push them with provisioners

**How it works**

1. Add the [`vancluever/acme`](https://registry.terraform.io/providers/vancluever/acme/latest/docs) provider to the module and configure it with your ACME account and Namecheap DNS credentials.
2. Use `acme_certificate` resources with the DNS-01 challenge to produce keys and certificate files under `~/.terraform.d` on the deployer.
3. Attach a `null_resource` (or the existing Lightsail instance resource) with `file` and `remote-exec` provisioners to copy the generated files into `/etc/letsencrypt` (or another directory) on the VM during `terraform apply`.
4. Disable or gate the certificate-generation tasks inside the solution playbooks when Terraform supplies the files.

**Why it can work**

- Keeps the entire workflow in Terraform, so state captures certificate issuance and renewals.
- Provisioners can ensure the certificate lands on the machine before Docker/Nginx containers start.

**Trade-offs / caveats**

- Terraform provisioners run on every instance replacement—because the module forces a new Lightsail instance on each apply for blue/green refreshes, you will exhaust Let’s Encrypt duplicate-certificate limits quickly unless you store and reuse the issued certificate across runs.
- Terraform state will contain sensitive private key material unless you externalize it; the backend must be encrypted and access-controlled.
- Provisioner failures are hard to recover from in Terraform because they leave partially created resources that require `terraform taint` or manual cleanup.

## 3. Stand up a temporary validation endpoint before deployment (Generally impractical)

**How it works**

1. Assign the Lightsail static IP to an existing staging host or a local reverse proxy that you control.
2. Run an ACME client with the HTTP-01 challenge against that temporary endpoint, serving the `/.well-known/acme-challenge` responses.
3. After issuance, release the static IP back to Terraform and let it attach to the new Lightsail instance, then push the certificate bundle during provisioning.

**Why it rarely works well**

- HTTP-01 requires the challenge responder to be publicly reachable at the final domain, which is difficult before the new VM exists.
- Reassigning the static IP to a staging host introduces downtime for existing clients and complicates automation.
- The choreography is fragile—any timing slip or failed IP reassignment causes the challenge to fail.

**Trade-offs / caveats**

- Namecheap's Dynamic DNS updates may lag, so the HTTP-01 challenge can still point to the wrong host during validation.
- Maintaining a staging host purely for certificate issuance defeats the simplicity of the current one-command deployment.

## Operational considerations common to all approaches

- Because the Terraform module purposely forces a new Lightsail instance name on every apply to trigger blue/green replacements, plan for certificate reuse or renewal logic that survives frequent instance churn.
- Store issued certificates somewhere durable (object storage, Vault, password manager) so you can reapply them without reissuing every time.
- Update the solution playbooks to respect externally supplied certificates—e.g., skip ACME tasks when files already exist—to avoid unintentional overwrites during first boot.
- Document the new secrets flow so operators know where Namecheap API tokens and private keys live and how to rotate them.
