# Proxy architecture and resilience

Terraform creates a Lightsail VM from the current selected blueprint and renders cloud-init. Cloud-init configures persistent 2 GB swap, bounded journals and disabled background APT maintenance, then writes `kho=off` into GRUB. When needed, one provisioning reboot activates the flag before package installation. A local systemd oneshot resumes bootstrap, writes `/var/lib/proxy-bootstrap/complete`, and removes its resume script. Refuse a repeated reboot if the flag is not active.

For `basic-vm`, install only CA certificates, curl, Python3, GPG and lsb-release. The separate Reality repository runs Ansible on a GitHub runner to install Docker and configure Xray. Do not install a local Ansible virtual environment for this path. Legacy solution modes retain their required local automation.

On a small Lightsail VM, swap buffers memory spikes but cannot compensate for all kernel allocation limits. Bound journald to 100 MB persistent and 32 MB runtime storage; bound Xray Docker logs to three files of 10 MB. There are no routine host or container reboot jobs. Docker's restart policy recovers process exits.

Cloud-init completion on the first boot is not sufficient readiness: wait for the resumed bootstrap completion marker and active boot policy. Verify package state, update policy, kernel version and authenticated proxy traffic before promotion.

Use two serving VMs and replace one at a time. Preserve a tested peer, validate and monitor the replacement, then retire the old VM and release its static IP. See [disposable VM strategy](disposable-proxy-vms.md) for the update policy, security review, monitoring and cleanup procedure. No kernel-version override or package hold is introduced.
