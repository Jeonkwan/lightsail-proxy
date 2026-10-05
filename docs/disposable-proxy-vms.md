# Disposable proxy VM strategy

Operate two independent Lightsail proxy VMs and use authenticated client URL testing for failover. Update by replacing one VM at a time, preserving a known-working peer. Client failover cannot guarantee availability during a shared network/provider outage.

Use the current supported Ubuntu Lightsail blueprint in the chosen region and zone. Do not pin or hold an old kernel. Record blueprint, instance identity, running kernel, Docker version and Xray image/digest for each deployment. A current blueprint can lag upstream package security fixes: check its patch level and release/security notices before promotion. If it lacks an urgent fix, select a corrected image or perform a controlled provisioning-only update before serving traffic; never silently leave a known vulnerable image indefinitely.

Default ongoing maintenance policy:
- No daily/periodic host or container reboot.
- No unattended APT refresh, download or package upgrade; APT services/timers are masked and periodic settings disabled. Existing package transactions are allowed to finish, never killed.
- No automatic update-triggered reboot. Explicit provisioning installs remain allowed.
- Bound persistent journal storage to 100 MB and runtime journal storage to 32 MB; Xray json-file logs use max-size 10m and max-file 3.
- Xray uses a reviewed version tag; record its resolved digest. Docker restart policy recovers process failures. No automatic container image updater.
- Manual APT access remains available for recovery; no kernel holds are introduced.

Basic-VM cloud-init installs only CA certificates, curl, Python3, GPG and lsb-release. Ansible executes on the GitHub runner; Docker is installed during the separate proxy deployment. Legacy deployment modes retain the tools their local playbooks need. Small-host swap remains configured.

Set kho=off in a GRUB drop-in and regenerate GRUB. This disables Kexec HandOver where supported without selecting a kernel version. Activate it with one controlled provisioning reboot before package installation on a small VM. A local systemd oneshot resumes the rendered bootstrap after reboot, marks completion and removes the resume script. Refuse a repeated reboot if the flag is still absent. Cloud-init completion alone is not readiness: require /var/lib/proxy-bootstrap/complete, current-boot kho=off and successful service status. Proxy deployment enforces the update policy and fails before deploying Xray if boot policy is not active; it never schedules a reboot itself.

Replacement workflow:
1. Choose a spare client-configured name, deploy new infrastructure in an isolated Terraform workspace, verify the plan contains only new resources, and preserve both serving peers.
2. Wait for the provisioning reboot and completed bootstrap. Verify current blueprint kernel is retained, no kernel holds, no background upgrade timers, no routine reboot jobs, bounded journals, healthy disk and clean package state.
3. Deploy the proxy from the reviewed feature commit and validate actual authenticated VLESS/REALITY HTTPS traffic. Confirm serving peers still work and test client failover where available.
4. Repeat deployment and confirm host boot and existing Xray container do not change. Perform one controlled reboot for persistence/recovery validation, then monitor at least 24 hours without scheduled maintenance.
5. Promote only after validation and monitoring. Replace one old VM, then repeat for its peer. Delete retired instance, static IP, key pair, matching snapshots and empty Terraform workspace; park or update retired DNS. Retain shared GitHub credentials/backends used by surviving VMs.

Review replacements monthly and act sooner for relevant security advisories. Replacement is the patch mechanism, not a reason to stop patching. No product PR is merged without owner confirmation.

Current test scope: new Flat White from scratch in Singapore zone a; Cream and Decaf remain untouched. Live credentials exist only in GitHub Actions environments; never put client UUIDs/private keys in evidence or docs.
