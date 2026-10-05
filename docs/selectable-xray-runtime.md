# Selectable Xray runtime

Provision a `basic-vm` with Lightsail first, then deploy from the Ansible controller
using `Jeonkwan/less-vision-reality`. Runtime selection belongs to proxy deployment,
not Terraform/bootstrap. Basic provisioning stays minimal for either runtime and
performs its one controlled reboot before marking bootstrap ready. Proxy deployment
never installs Ansible on the VM or schedules a reboot.

Both runtime defaults are now 26.3.27. Docker 25.10.15 remains an explicit reviewed
rollback (`-e xray_container_image_version=25.10.15` / Actions
`container_image_version=25.10.15`); diagnostics must select that same version.
The version fields remain separate so a native rollback does not silently change Docker.

## Defaults and contract

| Setting | Native | Docker |
| --- | --- | --- |
| `xray_deployment_mode` / Actions `deployment_mode` | `native` (default) | `docker` |
| Version | `xray_binary_version=26.3.27`; reviewed `25.10.15` available | `xray_container_image_version=26.3.27` |
| Actions version input | `xray_version=26.3.27` (native binary only) | `container_image_version=26.3.27` |
| Runtime | verified official archive binary, dedicated unprivileged `xray` account | official `ghcr.io/xtls/xray-core:26.3.27`, Compose |
| Config | `/usr/local/etc/xray/config.json`, root:xray 0640 | `/opt/xray/config/config.json`, root:65532 0640 |
| Runtime files | `/usr/local/bin/xray`, `/etc/systemd/system/xray.service` | `/opt/xray/docker-compose.yml`; Compose project/service `xray` |
| Logs | journald; no text logs/logrotate | json-file, 10 MB × three files |

Both modes share the same VLESS/REALITY settings, credentials and host policy.
Host journald uses persistent 100 MB, runtime 32 MB, 10 MB files, seven-day
retention and no syslog forwarding. Validate retained disk usage with allocated
blocks (`st_blocks * 512`, matching `journalctl --disk-usage`), because archived
journal files can reserve sparse logical space without using that disk capacity. Swap, active `kho=off`, held snap refresh and
disabled background APT maintenance remain unchanged. No floating tags or automatic
runtime updates are introduced. Unsupported selectors, versions and managed path
changes fail before host operations. Initial support remains Ubuntu/systemd x86-64.

Native downloads, checksum verification and extraction run on the controller,
using `scripts/prepare-native.py`; direct Ansible downloads automatically when no
prepared artifact is supplied. Actions prepares the same verified artifact on its
runner. Installed and staged binary SHA-256 checks remain mandatory. Native installs
no Docker, Compose, compiler or admin tools. Docker installs missing curl, GPG,
CA certificates and lsb-release before configuring its repository, then Engine
and the Compose plugin. It uses builtin Ansible modules: no Docker SDK or Galaxy
collection. Credential generation may independently use Docker on the controller.

## Choosing a runtime

From the proxy repository root, with an inventory under `xray_servers`, credentials
in Vault or `XRAY_UUID`, `XRAY_SHORT_IDS`, `XRAY_PRIVATE_KEY`, `XRAY_PUBLIC_KEY`, and
optional `XRAY_SNI` already supplied securely:

```bash
ansible-playbook -i /path/to/inventory.yml ansible/site.yml \
  -e xray_deployment_mode=native -e xray_binary_version=26.3.27
ansible-playbook -i /path/to/inventory.yml ansible/site.yml \
  -e xray_deployment_mode=docker -e xray_container_image_version=26.3.27
```

`XRAY_DEPLOYMENT_MODE` is the environment equivalent; `-e` takes precedence. Native
artifact preparation can also be run explicitly using `scripts/prepare-native.py
--version 26.3.27 --directory /controller/artifacts/xray --github-env /controller/artifact.env`;
export its `XRAY_BINARY_PATH` and `XRAY_BINARY_SHA256` for the subsequent playbook.
Keep artifact directories outside tracked files. Never use placeholder credentials
for deployment.

Actions example (environment names are operator-selected credential stores):

```bash
gh workflow run deploy.yml --repo Jeonkwan/less-vision-reality \
  --ref main \
  -f environment=YOUR_ENVIRONMENT -f remote_server_ip_address=SPARE_IP \
  -f remote_server_user=ubuntu -f deployment_mode=native -f xray_version=26.3.27
gh workflow run deploy.yml --repo Jeonkwan/less-vision-reality \
  --ref main \
  -f environment=YOUR_ENVIRONMENT -f remote_server_ip_address=SPARE_IP \
  -f remote_server_user=ubuntu -f deployment_mode=docker -f container_image_version=26.3.27
```

The reusable workflow exposes the same selection as a string and rejects invalid
values. Manual dispatch exposes a native/docker choice. No secrets need exporting
from GitHub Actions. Keep the existing infrastructure `terraform-deploy.yml` intact;
its `proxy_solution=basic-vm` prepares the host, not an Xray runtime. The guarded
`native-infrastructure.yml` becomes registered when this PR chain merges into main;
it and the optional selected-host path provision a basic VM for either runtime.

## Switching and rollback

First select one host (`--limit` for multi-host inventories), preserve a healthy
peer, and record diagnostics/client results and current versions. A runtime switch
has a brief interruption. Opposite active Docker containers or active/enabled native
services require `xray_allow_runtime_switch=true`; Actions uses
`allow_runtime_switch=true`. Inactive retained artifacts do not require opt-in on
normal repeats. Ownership is checked before deployment: native unit content and
paths, or Docker Compose labels, working directory, config file and bind mount.
Ambiguous units/containers/configuration fail closed. Docker daemon errors are not
interpreted as absence; an installed daemon must be inspectable. Unrelated port
listeners cause failure; deployment never removes them.

```bash
# Native -> Docker
ansible-playbook -i /path/to/inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=docker -e xray_allow_runtime_switch=true
# Docker -> native, also rollback of the preceding switch
ansible-playbook -i /path/to/inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=native -e xray_allow_runtime_switch=true \
  -e xray_binary_version=26.3.27
# Reviewed native version rollback
ansible-playbook -i /path/to/inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=native -e xray_binary_version=25.10.15
```

The pinned Docker image runs as UID/GID 65532. Its bind-mounted config directory
is root:65532 0750 and config/candidate files are root:65532 0640; no host account
is installed for that numeric identity. Compose remains root-only.

Docker validates the candidate in an isolated temporary container with no network
or published ports, then validates Compose. Native validates the candidate binary
and config pair. Only afterward does deployment stop the verified opposite runtime:
native is disabled, or the exact Docker container is stopped (`unless-stopped`
keeps it stopped across daemon/host restart). Activation checks port availability
across IPv4/IPv6 and requires the selected runtime/listener. If activation fails,
Ansible attempts to stop the selected runtime and restore the previous opposite
runtime, then reports failure. This is best-effort recovery, not a guarantee against
host/daemon failure; inspect the host before retrying. Invalid candidates leave the
serving runtime intact. Same-mode post-activation failures need operator diagnosis
and redeployment of the last reviewed configuration/version.

Inactive binary/config/unit, Docker container and packages are retained for rollback.
No containers, networks or unrelated config are removed; no `--remove-orphans`,
prune, port-based cleanup or global Docker stop is used. A Docker -> native switch
therefore retains Docker packages. A fresh native VM is the way to obtain the minimal
package footprint. Normal unchanged deployment preserves the running native process
or Docker container and host boot. A config change explicitly recreates the Docker
container because bind-file contents alone do not trigger Compose recreation.

Lifecycle tags always honor the selector and ownership guard:

```bash
ansible-playbook -i /path/to/inventory.yml ansible/site.yml \
  -e xray_deployment_mode=native --tags xray_down
ansible-playbook -i /path/to/inventory.yml ansible/site.yml \
  -e xray_deployment_mode=docker --tags xray_reload
# Either mode: xray_down stops; xray_reload restarts;
# xray_recreate explicitly restarts native or recreates Docker.
```

These tags act on existing deployments; they do not install packages or stage config.
To restore a stopped service, use a normal deployment. Lifecycle stop is temporary
for native (its existing enablement is retained); use an explicit switch to disable
it when selecting Docker.

## Diagnostics and validation status

`diagnose.yml` accepts `deployment_mode`, the credential `environment`, explicit
`target` and expected `address`. Stages cover readiness, clients, inspection,
baseline/compare, failure recovery, reboot and log rotation. Use
`require_minimal_host=true` only for a freshly provisioned native host. Native
inspection allows inactive retained Docker artifacts after a switch but rejects a
running managed Docker peer. Docker inspection requires the pinned running image,
bounded json-file logs and disabled/stopped native unit. Baselines compare boot plus
native PID/start/restarts or Docker ID/PID/start/restarts. Mutation stages still
require the selected hostname to resolve to the expected IP. Existing cream/flatwhite/decaf profiles and fingerprints remain unchanged. Americano
and Latte add sanitized copies of the supplied compatible transport settings, with
only labels/addresses changed; other spare names need reviewed profile/target support.

Local checks execute selector dispatch and reject invalid modes before host operations,
exercise ownership rejection, verify archive corruption rejection, and validate the
shared config with both reviewed official binaries. CI checks both modes and exercises
config permissions against the actual pinned nonroot Docker image. Historical two-mode acceptance
used the owner-selected Americano and Latte spares; see the separate
[validation record and commands](selectable-runtime-validation.md) for current status.
Previous native-only evidence cannot establish selectable-runtime correctness.

## Historical Americano/Latte acceptance and cleanup

For a future two-mode run, obtain a selected disposable target and mutation/cleanup scope first.
The earlier owner scope selected Americano (zone A) and Latte (zone C), including destruction
after validation. This task-specific authorization does not extend to serving peers.

1. Use isolated Terraform workspaces and the guarded registered spare workflow. It
   checks ownership and a plan containing only selected resources. Preserve existing
   Namecheap DNS and use temporary `name.IP.sslip.io` names bound to the recorded IP.
2. Provision basic-vm, wait for completed bootstrap and active `kho=off`; record
   instance/IP/kernel/boot and check Flat White/Decaf with read-only Actions clients.
3. Start Americano fresh with native 26.3.27 and prove Docker absent. Start Latte fresh
   with pinned Docker 25.10.15. On each host authenticate sing-box 1.11.4 and mihomo
   1.19.32 against both IP and temporary hostname using the supplied transport profile.
4. Record a baseline; unchanged redeployment, invalid mode and invalid candidate must
   preserve runtime/boot and clients. Test SIGKILL recovery, reboot and actual bounded
   journal or Docker json-file rotation. Detect newly created journal archive names
   rather than requiring a growing file count: retention can delete older archives.
   Native still checks host journal retention;
   Docker checks both host journals and its own logs.
5. Refuse switching without opt-in, then switch to the opposite runtime, repeat the
   lifecycle suite and roll back. Preserve an unrelated container/network/config
   fixture across switches and reboots, then remove only the harness-created fixture.
   Ambiguous ownership and unrelated-listener guards also have local coverage.
6. Recheck serving peers, destroy each exact recorded spare identity and confirm
   instance/static IP/key/snapshots and empty workspace removal. Record sanitized
   acceptance and teardown run links. Never leave spares running to await merge.

Merge, releases and serving-node deployment require separate owner instructions.

Client checks require two successful samples per endpoint/engine/address. Transient
network errors receive at most three attempts per required request, with every retry
logged; persistent network, HTTP or configuration failures fail validation.

Runner client success covers supplied proxy transport, not complete iOS TUN/DNS or
a mobile ISP path. No credential values, state or unfiltered logs belong in evidence.

## Cream replacement acceptance

The owner selected a fresh Cream for Docker-only 26.3.27 deployment and authenticated
sing-box/mihomo IP and hostname checks. Keep Cream on success, retire exact Flat White
and all owned resources, park `flatwhite.mokamaker.site`, and preserve Decaf. No new
reboot/failure/log-injection suite or monitoring delay is required for this follow-up.
The earlier two-mode suite above remains historical evidence for 25.10.15 Docker.

Before default-branch registration of `native-infrastructure.yml`, use the registered
selected-host path without overwriting normal workflow behavior:

```bash
gh workflow run terraform-deploy.yml --repo Jeonkwan/lightsail-proxy \
  --ref main -f workspace=cream -f tf_action=plan \
  -f instance_operation=inspect -f instance_target=cream
# After inspection confirms no Cream resources, change inspect to create.
# After Cream acceptance, retire only the recorded Flat White identity:
gh workflow run terraform-deploy.yml --repo Jeonkwan/lightsail-proxy \
  --ref main -f workspace=flatwhite -f tf_action=plan \
  -f instance_operation=destroy -f instance_target=flatwhite \
  -f expected_instance=EXACT_RECORDED_FLATWHITE_INSTANCE
```

Choose exactly one optional operation path. It checks isolated workspace ownership,
plan scope and peer identities; destruction requires an exact instance name. Credentials
remain in Actions. After merge, use `--ref main` and the registered infrastructure
workflow as appropriate. See the validation record for current production identities.
