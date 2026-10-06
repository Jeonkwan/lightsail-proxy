# Podman runtime validation — 2026-10-06

Owner-approved scope: add rootful Podman as an extra runtime, preserving native
and Docker. Only disposable flatwhite may be mutated. Decaf and Cream are excluded.
No merge or release is authorized.

## Baseline and isolated host

Implementation starts from both published v2.2.0 main commits: proxy
`8d062e286943dd3b4f3c2829cfac8e567c79dda5`, infrastructure
`8e13b8794b46501880f49de2da43ea4dd4e0bb54`.

[Preflight inspection](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37416856247)
identified serving Decaf and Cream and confirmed the disposable scope.
[Guarded creation](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37417144019)
created `lightsail-singapore-a-flatwhite-20261006051026`, `18.141.16.60`,
owned static IP/key and workspace `flatwhite`. DNS temporarily points
`flatwhite.mokamaker.site` at that IP. Existing shared credentials stay in Actions.

## Compatibility finding and checks

The initial deployment validated configuration but failed actual TCP startup.
[Read-only kernel evidence](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37418845436)
showed crun/AppArmor denial of socket creation with the optional Podman
no-new-privileges flag, matching Ubuntu bug
[2118824](https://bugs.launchpad.net/ubuntu/+source/libpod/+bug/2118824).
Omit that optional flag while retaining UID/GID 65532, zero effective/permitted/
bounding capabilities, default AppArmor/seccomp, private bridge networking and a
read-only config mount. No global AppArmor policy change. Container specification
v2 replaces the earlier failed definition without relying on config/image changes.

[Corrected deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37419095197)
passed. [Three-runtime CI](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37419099945)
passed native, Docker and Podman paths. Actual rootful Podman tests check both
reviewed images (26.3.27 and 25.10.15), real config permission acceptance/rejection,
and actual TCP startup. Local ownership/switch tests cover all six opt-in and
activation-failure recovery conditions, ambiguity and unrelated published ports.
Infrastructure Terraform/bootstrap/ownership checks also passed.

## Live acceptance

[Initial focused run](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37419346942)
passed fresh Docker-free footprint, host policy, supplied clients, unchanged
identity/process/boot and invalid selector/config guards. It then correctly rejected
an accidentally 17-character short ID in the harness's intended valid change.
The test value was corrected to 16 characters; this was a harness input error,
not a deployment defect. Earlier fresh-footprint evidence is retained. Live inspection recorded rootful
Podman 4.9.3, Xray 26.3.27 and kernel `7.0.0-1012-aws`; Linux/amd64 image ID
`695c08e5627556d1286f43ae3aeb370679d27b969ba0d5bb3dfe288746a5dde9`.
Configuration ownership/permissions, UID/GID 65532, zero process capabilities,
default AppArmor, inactive opposites and existing bounded host policy passed.

[Resumed focused run](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37420089923)
passed changed deployment, all Podman lifecycle tags, SIGKILL recovery, actual
container journald rotation (8 files, 56,766,464 allocated bytes), transitions to/from
native and Docker, opt-in refusals and preservation of unrelated container fixtures.
After final reboot Xray restarted, but client traffic failed.
[Read-only forwarding evidence](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37423033440)
showed Docker starting after Podman and setting default FORWARD policy to DROP;
Ubuntu netavark's rules allowed established/in-subnet traffic but omitted a new
inbound allowance for the published port. The fix adds/removes one owned DNAT-only
TCP 443 allowance for the inspected container IPv4 address. It never changes global
policy or flushes rules. Tests cover idempotence, replacement, exact cleanup,
untrusted records and inspection failures. [Forwarding-fix deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37424599395)
and [installed-rule/host/client inspection](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37424949650)
passed. [Forwarding-fix three-runtime CI](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37424321484)
passed. The [focused final follow-up](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37426702910)
passed on 2026-10-06: unchanged deployment preserved process/container/boot and
forwarding; stop removed the exact owned rule and record; crash recovery restored
one rule; native switch removed it and return restored it; unrelated forwarding
rules were preserved; and reboot plus both supplied clients by IP/hostname passed.
All five final Podman inspections recorded `FORWARD DROP` with the owned allowance
present, proving healthy transport under the previously failing policy. Both
tracked container fixtures were cleaned in the earlier run. All agreed gates pass.

Review also tightened lifecycle activation: restart/recreate tags cannot bypass
normal candidate-validated switching, even with switch opt-in. Executable Ansible
dispatcher tests cover all six cross-mode refusals and each same-mode acceptance.
The harness checks fresh Docker-free Podman deployment; supplied sing-box 1.11.4
and pinned mihomo 1.19.32 transport by IP/hostname; unchanged/changed deployment;
invalid selector/candidate; Podman lifecycle, crash recovery and actual journald
rotation; transitions to/from native and Docker with opt-in refusals; unrelated
container fixtures; and final Podman reboot. Existing native/Docker lifecycle
suites are not repeated. No peer fallback is permitted.

Runner transport success does not establish complete iOS TUN/DNS or mobile ISP
behavior. Live acceptance uses Xray 26.3.27; 25.10.15 Podman compatibility evidence
is limited to actual image/config/startup CI checks.

## Teardown

[Exact-identity destruction](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37428408888)
completed on 2026-10-06 after all agreed gates passed. Exactly six owned resources
were destroyed. The helper verified instance, static IP, key and matching snapshots
absent, confirmed empty state, deleted workspace `flatwhite`, and parked DNS.
Independent Google DNS-over-HTTPS resolution returned `127.0.0.1` for
`flatwhite.mokamaker.site` (response from authoritative server `156.154.132.200`).
No flatwhite validation resources remain. Shared credentials/environments/backends
were retained.

The cleanup guard confirmed these serving identities and addresses unchanged:

| Node | Instance | Address | Existing runtime |
| --- | --- | --- | --- |
| Decaf | `lightsail-singapore-c-decaf-20261005103556` | `52.74.81.140` | Native 26.3.27 |
| Cream | `lightsail-singapore-a-cream-20261005165610` | `18.136.58.134` | Docker 26.3.27 |

Neither serving node was redeployed, rebooted, destroyed or used as client fallback.
This completed authorization is task-specific; future cloud mutations require a
new selected scope. No merge or release was performed.
