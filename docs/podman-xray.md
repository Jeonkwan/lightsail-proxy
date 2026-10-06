# Podman Xray runtime

Select `xray_deployment_mode=podman` through Ansible or Actions
`deployment_mode=podman`. Native remains the default; Docker/Compose remains a
separate supported mode. Lightsail still provisions `basic-vm`; no Terraform
proxy_solution or bootstrap runtime installation is added.

## Runtime contract

Initial support is Ubuntu 24.04/systemd x86-64 with rootful distribution Podman
4.9 or newer and cgroup v2. Install Podman, netavark, aardvark-dns and iptables only when
this mode is selected. No Docker CE, Docker compatibility socket/alias, Compose,
Python Docker SDK or Galaxy collection is required on a fresh Podman host.
Existing engine packages are retained after switches.

Use `xray_container_image_version=26.3.27` (Actions `container_image_version`)
for the official `ghcr.io/xtls/xray-core` image. Binary and image version settings
remain separate. The explicit reviewed 25.10.15 container option is checked in
CI; live flatwhite acceptance uses 26.3.27. No floating tags or automatic updates.

Podman has no daemon. A regular `/etc/systemd/system/xray-podman.service` starts
and stops the inspected container ID through an ownership helper, using local
rootful storage (`--remote=false`). Systemd `Restart=always` provides failure
recovery; an intentional systemctl stop does not restart the container. Disable
the service when switching away so it stays stopped across host reboot. Native
`xray.service`, Docker Compose `xray`, and Podman `xray-podman` are distinct.

The Xray process runs as UID/GID 65532 with all capabilities dropped. Default
AppArmor/seccomp confinement stays enabled. Ubuntu 24.04 crun/AppArmor stacking
can deny TCP creation with the optional no-new-privileges flag (Ubuntu bug
[2118824](https://bugs.launchpad.net/ubuntu/+source/libpod/+bug/2118824)); this mode
omits that flag and does not alter global AppArmor policy. Validate actual TCP
startup and zero effective/permitted/bounding capabilities, not only config parsing.
Its private network namespace permits binding its container port 443
using an explicit namespace sysctl; bridge networking publishes TCP 443. The
service does not use host networking or privileged containers. Systemd installs a
single owned IPv4 forwarding allowance after startup, restricted to this container's
address, TCP 443 and DNAT traffic. It removes that exact rule on stop/failed startup,
using a private atomic `forwarding.json` ownership record. This keeps published
traffic working when a retained Docker daemon sets FORWARD policy to DROP after
reboot. No global policy changes, rule flushes or unrelated forwarding rules are
issued by this helper. Configuration is
`/opt/xray-podman/config/config.json`, root:65532 0640, with a read-only bind mount.
The deployment root and ownership helper are root-only. Podman's journald log
driver uses existing host retention: persistent 100 MB, runtime 32 MB, 10 MB files,
seven days, no syslog forwarding. Supervisor stdout is discarded to avoid a
second copy of container output. Existing swap, KHO and maintenance policy remains.

## Deployment, switching and lifecycle

```bash
ansible-playbook -i inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=podman -e xray_container_image_version=26.3.27
# Switching from native or Docker needs deliberate opt-in:
ansible-playbook -i inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=podman -e xray_allow_runtime_switch=true
# Switching back uses the same guard:
ansible-playbook -i inventory.yml ansible/site.yml --limit spare \
  -e xray_deployment_mode=docker -e xray_allow_runtime_switch=true
```

Before modifications, inspect all managed runtimes. Verify the Podman marker,
service definition, container labels, image/user, read-only config mount, ports,
logging and supervisor. Ambiguous resources, inspection errors, rootless storage,
unknown units or service overrides fail closed. Reject unrelated engine port
mappings even if they have no userspace socket, then enforce IPv4/IPv6 listener
availability during activation. No global engine stops, prune or orphan removal.

Validate the selected image and candidate configuration in an isolated container
without network or published ports; validate the supervisor before stopping the
verified opposite runtime. On activation failure, attempt to stop the failed
selected runtime and restore the recorded previous runtime/enablement. This is
best-effort recovery: inspect the target before retrying. Invalid candidates leave
the serving runtime intact. Same-mode activation failure requires operator
inspection and redeployment of the last reviewed configuration/version.

Unchanged deployment preserves the Podman container, process and host boot.
Changed configuration or image replaces only the recorded owned container.
`--tags xray_down` stops the selected service; `xray_reload` restarts it;
`xray_recreate` recreates only the inspected existing Podman container with its
reviewed image version and existing config. Lifecycle tags do not install packages
or stage deployment candidates. Activation tags refuse an opposite active/enabled
runtime even with switch opt-in; switch through normal deployment first. Restore a
stopped service through normal deployment.

## Focused validation and scope

The owner authorized flatwhite creation, redeployment and recreation for this
change, with teardown after all agreed checks pass. Decaf and Cream are excluded
from mutations. Existing GitHub Actions environments hold credentials; never
export them into this workspace or commit client configs/state.

Use `diagnose.yml` with `target=flatwhite`, the recorded `address`,
`deployment_mode=podman`, `stage=validate-podman`, and the matching credential
environment. The focused harness checks a fresh Docker-free Podman host, supplied
sing-box 1.11.4/mihomo 1.19.32 transport against IP and hostname, unchanged and
changed deployment, invalid selector/config, lifecycle tags, crash recovery,
actual container-to-journald rotation, transitions to/from both native and Docker,
unrelated fixtures, and one final Podman reboot. It does not repeat historical
native/Docker lifecycle suites or impose a soak. All six switch opt-in/recovery
conditions also have executable local tests.

`resume_spare=true` is only for a failed attempt after fresh footprint evidence was
already recorded. Run explicit target client checks: no peer fallback is permitted.
Runner transport checks do not establish complete iOS TUN/DNS/mobile behavior.
After earlier gates have recorded evidence, `stage=validate-podman-final` with
`resume_spare=true` runs only the affected forwarding-hook follow-up: unchanged
deployment, stop/rule cleanup, crash recovery, native switch cleanup/return, and
reboot/client inspection while retaining unrelated forwarding rules.

After acceptance, destroy the exact recorded flatwhite instance and owned static
IP/key/snapshots, delete its empty workspace, and park flatwhite.mokamaker.site at
127.0.0.1. Keep shared credentials/backends. Merge and release need separate owner
instructions. The authorized flatwhite acceptance and teardown completed on 2026-10-06.
See the [Podman validation record](podman-runtime-validation.md) for actual results
and run links.
