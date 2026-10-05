# Native Xray validation — 2026-10-05

Historical native-only evidence. For selectable native/Docker deployment, use the
[runtime contract](selectable-xray-runtime.md) and
[spare acceptance record](selectable-runtime-validation.md).

Both repositories use `feature/native-xray`, based on `feature/bounded-logs`.
For the subsequent Decaf replacement, see [Decaf native validation](decaf-native-validation.md).
Product PRs remain draft and unmerged. The owner authorized fresh Cream testing,
Flat White replacement, and Cream retirement after Flat White passed; no 24-hour
soak was required.

## Client coverage

Used the supplied Clash and sing-box VLESS/REALITY Vision transport profiles:
SNI `web.wechat.com`, Chrome fingerprint, matching UUID/public key/short ID.
Credentials came from existing Actions environment secrets and were checked against
one-way profile fingerprints. Personal client files were not committed.
Pinned mihomo 1.19.32 and sing-box 1.11.4 ran on GitHub runners, each making
repeated authenticated HTTPS requests to Cloudflare and Google through both the
static IP and hostname. These tests cover the proxy transport, not the complete
iOS TUN/DNS setup or a mobile ISP path.

## Results

| Validation | Result / evidence |
|---|---|
| Fresh Cream, native 25.10.15 | [Deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37284062744), [both clients](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37284516240): passed |
| Invalid candidate configuration | [Expected deployment rejection](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37285081527); [comparison](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37285577760) confirmed serving PID/boot unchanged and clients passed |
| Cream, latest stable 26.3.27 | [Upgrade](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37285725523), [full suite](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37286117540): passed, 96 successful HTTPS requests |
| Cream unchanged redeployment | [Deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37286505111), [comparison](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37286988634): passed |
| Fresh Flat White, 26.3.27 | [Instance replacement](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37287106377), [deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37287513222), [full suite](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37287912787): passed, 96 successful HTTPS requests |
| Flat White unchanged redeployment | [Deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37288282760), [comparison](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37288549616): passed |
| Cream retirement | [Destroy](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37288646009), [inventory](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37288882049): instance/static IP/key/snapshots absent, workspace deleted, DNS parked to 127.0.0.1 |
| Final serving checks | [Flat White](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37288662919), [Decaf](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37288901031): passed |

Full suites verified no Docker or Ansible on the hosts, service enabled and running
as the unprivileged xray account, configuration permissions, bootstrap/kernel and
maintenance policy, and effective journal retention. SIGKILL recovery changed the
PID without rebooting; reboot recovery changed the boot ID and restored working
clients. Unchanged redeployment preserved PID, start timestamp, restart count and
boot ID. Journal probes produced actual rotation: Cream retained 54,525,952 bytes,
Flat White 94,371,840 bytes, within the 100 MB budget plus active-file allowance.

## Timing and state after the initial migration

The Ansible portion measured about 84 seconds for Cream/25.10.15, 121 seconds for
Cream/26.3.27, and 149 seconds for fresh Flat White/26.3.27, versus about 300 seconds
for the earlier container deployment. This is not an isolated Docker benchmark:
pipelining, bootstrap changes and removal of a fixed wait also contribute, and
runner/SSH transfer times vary. Infrastructure provisioning and client DNS are
outside those Ansible durations.

Flat White is `lightsail-singapore-a-flatwhite-20261005090040`, retaining static IP
54.179.39.30 and existing credentials. Decaf remains
`lightsail-singapore-c-decaf-20260730010620`, 52.74.81.140. Cream is retired.
Xray 26.3.27 was reconfirmed as the official GitHub latest non-prerelease and is the
pinned deployment default; 25.10.15 remains an explicit rollback option.
