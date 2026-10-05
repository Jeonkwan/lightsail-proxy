# Native Xray deployment

For selectable native/Docker deployment, switching and the spare-validation plan, see [selectable runtime](selectable-xray-runtime.md).

The managed basic Ubuntu VM needs SSH, Python3 and CA certificates already present
on normal blueprints. Missing requirements are installed conditionally. Ansible,
archive downloads, checksum verification, extraction and test clients run on the
control host. Initial support is Ubuntu/systemd on x86-64; the binary itself is
portable, but other architectures/distributions need separately reviewed artifacts
and host-policy support.

`prepare-native.py` accepts only reviewed pinned releases (25.10.15 baseline,
26.3.27 latest stable at review and validated default). Official archive SHA-256 is checked before extracting
only the binary. No geodata, Docker, Compose, compiler or Python packages are
installed on the VM. Configuration is validated with the candidate binary before
activation. An unchanged deployment preserves the running process and host boot.
Use explicit `xray_down` / `xray_reload` tags for lifecycle operations.

Native paths follow the official installer convention: `/usr/local/bin/xray`,
`/usr/local/etc/xray/config.json`, `/etc/systemd/system/xray.service`. A dedicated
unprivileged account receives only CAP_NET_BIND_SERVICE. Config is root:xray 0640.
Systemd restarts failed processes with a delay. Logs go to journald, capped host-wide
at 100 MB persistent / 32 MB runtime, 10 MB files and seven days. Journald rotates
these files; no logrotate/cron or separate Xray text logs are needed. Persistent
journal budgets have normal active-file slack, not a byte-exact instantaneous cap.

The deployment workflow accepts a reviewed `xray_version`. The diagnostics workflow
requires an explicit target and expected static IP and provides readiness, both
client-core checks, host inspection, unchanged-process comparison, reboot, failure
recovery and journal rotation. Client profiles contain only transport settings and
one-way identity fingerprints; actual credentials come from environment secrets,
and complete supplied personal client files are never committed. Runner tests
exercise the provided Clash/mihomo and sing-box proxy settings, not iOS TUN/DNS
integration or a particular mobile ISP path.

The initial sequence validated Cream, then fresh Flat White retaining its static
IP, and retired Cream. The follow-up replaces Decaf in Singapore zone C while
Flat White keeps serving. No 24-hour soak is required for these authorized tests.
Terraform operations support Cream/Flat White in zone A and Decaf in zone C.
They validate exact target identity and resource scope, preserve
other instances, and guard instance-only replacement so static IP/key/DNS remain.
Destruction removes owned snapshots, an empty workspace and parks retired DNS.
Both product PRs remain draft until explicitly approved for merge.

Guarded operations live in `.github/workflows/native-infrastructure.yml`; the
normal `terraform-deploy.yml` retains its existing inputs and deployment behavior.
GitHub requires a workflow to be registered on the default branch for manual
dispatch. During this draft's live validation, the guarded definition temporarily
used the already registered `terraform-deploy.yml` filename, which was restored
after cleanup. The separate native workflow needs registration before future
manual dispatch. See [validation evidence](native-xray-validation.md).
