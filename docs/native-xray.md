# Native Xray deployment

The managed basic Ubuntu VM needs SSH, Python3 and CA certificates already present
on normal blueprints. Missing requirements are installed conditionally. Ansible,
archive downloads, checksum verification, extraction and test clients run on the
control host. Initial support is Ubuntu/systemd on x86-64; the binary itself is
portable, but other architectures/distributions need separately reviewed artifacts
and host-policy support.

`prepare-native.py` accepts only reviewed pinned releases (25.10.15 baseline,
26.3.27 latest stable at review). Official archive SHA-256 is checked before extracting
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

Authorized sequence: clean Cream, baseline binary, latest stable binary, then fresh
Flat White retaining its static IP, then Cream cleanup after Flat White passes.
No 24-hour soak is required for this experiment. Keep Decaf serving throughout.
Terraform operations validate exact target identity and resource scope, preserve
other instances, and guard instance-only replacement so static IP/key/DNS remain.
Destruction removes owned snapshots, an empty workspace and parks retired DNS.
Both product PRs remain draft until explicitly approved for merge.
