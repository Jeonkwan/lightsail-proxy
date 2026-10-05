# Lightsail infrastructure Actions

Use Terraform 1.6.6, matching local tooling and CI. Verify local downloads against
HashiCorp's official checksum. The S3 backend in `config.tf` receives bucket, key
and region overrides from `TF_BACKEND_BUCKET`, `TF_BACKEND_KEY` and
`TF_BACKEND_REGION`. Terraform 1.6.6 does not provide the later S3 lockfile feature;
this configuration does not enable it. Serialize operations per workspace and
never force-unlock an active operation.

The registered `terraform-deploy.yml` runs with the `prod-basic` environment and
its existing AWS/SSH public key secrets. Normal dispatch preserves `workspace`,
`tf_action` (plan/apply/destroy/test-full-cycle), region/zone, solution and other
inputs. Existing push behavior is retained. Use `proxy_solution=basic-vm` for
controller-managed selectable Xray: provisioning and proxy deployment are separate.
Choose `deployment_mode=native|docker` in the sibling proxy workflow afterward.
See the [runtime contract](selectable-xray-runtime.md).

Optional `spare_operation=inspect|create|destroy` selects a separate guarded job,
only for `spare_target=americano|latte`. It uses the matching isolated workspace,
forces basic-vm and the expected Singapore zone, keeps DNS unchanged, verifies
resource plans/ownership and preserves all other instances. Destruction requires
`expected_instance` matching the sole owned spare. Empty `spare_operation` preserves
normal workflow behavior. Exact commands and current evidence are in the
[spare validation record](selectable-runtime-validation.md).

`native-infrastructure.yml` remains unregistered on the default branch and cannot
be manually dispatched until registered. Do not replace the normal workflow to
bypass this restriction; the registered guarded spare path handles this task.
Future cloud mutations need an explicitly selected target and authorized scope.
Do not export Actions secrets or commit state, secret tfvars or unfiltered logs.
