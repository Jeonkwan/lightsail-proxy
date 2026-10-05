# Decaf native replacement — 2026-10-05

Historical native-only evidence. For selectable native/Docker deployment, use the
[runtime contract](selectable-xray-runtime.md) and
[spare acceptance record](selectable-runtime-validation.md).

The owner authorized replacing Decaf after the initial Cream/Flat White native
migration. Flat White remained serving throughout. Existing release tags were
not moved; proxy deployments used the annotated `v2.1.0-native-xray` tag.
Guarded infrastructure/validation support was extended on `feature/native-xray`
to include Decaf in its existing Singapore zone C. Product PRs remain draft and
unmerged. For manual draft dispatch, the native infrastructure definition
briefly used the registered terraform-deploy filename; the general workflow was
restored after infrastructure verification.

## Deployment and cleanup

- [Initial ownership inspection](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37297202761) confirmed that the decaf Terraform workspace owned lightsail-singapore-c-decaf-20260730010620 in ap-southeast-1c, Ubuntu 24.04 / nano_2_0.
- [Replacement](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37297494021) destroyed the retired instance and created lightsail-singapore-c-decaf-20261005103556. Only instance/firewall/attachment resources changed; static IP, key pair and DNS were retained.
- [Inventory](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37297761252) confirmed the retained static IP 52.74.81.140 was attached to the new Decaf, the old instance/snapshots were absent, and Flat White remained lightsail-singapore-a-flatwhite-20261005090040 at 54.179.39.30.
- [Bootstrap](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37297742101) passed after the controlled provisioning reboot with kernel 7.0.0-1012-aws and active kho=off.
- [Native deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37297948795) installed reviewed official Xray 26.3.27 under systemd. Ansible took about 80 seconds, excluding infrastructure/bootstrap and runner setup.

## Validation

[Full suite](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37298208499)
passed on attempt 2. Attempt 1 remained queued with no assigned runner and was
cancelled; it did not execute host changes.

The suite verified both supplied sing-box and Clash/mihomo transport profiles
against IP and hostname, with 96 successful authenticated HTTPS requests. It
verified the service user and config permissions, no Docker/Ansible installation,
bootstrap/kernel/maintenance policy and effective journald retention. These are
runner proxy-transport tests; full iOS TUN/DNS/ISP behavior remains outside them.

Official archive SHA-256:
`23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae`.
Installed binary SHA-256, also verified after reboot:
`8255dd939c34cf966cc91517b6324dd3c8d0bcf49ffac8beca049a38c46845ed`.

The journal probe produced six journal files retaining 54,525,952 bytes within
the configured budget. SIGKILL changed PID 2454 to 3024 without rebooting, and
systemd recovered. A subsequent controlled reboot restored Xray and working
clients. The post-reboot baseline recorded PID 558 and zero restart count.

[Unchanged redeployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37299277068)
and [baseline comparison](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37299580638)
passed: PID/start timestamp/restart count/boot stayed unchanged, and both client
profiles passed again against IP and hostname.

[Flat White peer checks](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37298510578)
passed after replacement. Cream remains retired. Both serving nodes now use
native Xray 26.3.27; static IPs and client credentials were preserved. No 24-hour
soak or PR merge was performed.
