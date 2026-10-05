# Selectable runtime validation

Current serving nodes after the authorized replacement (2026-10-05):

| Node | Instance | Address | Runtime |
| --- | --- | --- | --- |
| Cream | `lightsail-singapore-a-cream-20261005165610` | `18.136.58.134` / `cream.mokamaker.site` | Docker/Compose, official Xray 26.3.27 |
| Decaf | `lightsail-singapore-c-decaf-20261005103556` | `52.74.81.140` / `decaf.mokamaker.site` | Native/systemd, verified Xray 26.3.27 |

The later Cream replacement section supersedes the historical serving-node status
below. Credentials and supplied transport settings remain compatible; secret values
stay in Actions. Americano/Latte remain retired.

## Historical Americano/Latte validation

The owner selected **Americano** (Singapore zone A) and **Latte** (Singapore zone C)
for disposable validation, including reboot/failure/log-rotation tests, runtime
switching and destruction afterward. Flat White and Decaf were the serving peers.

Americano started fresh in native mode; Latte started fresh in Docker mode. Each
then switched to the other mode and rolled back using explicit switch opt-in. Americano
resumed in Docker after retaining its earlier fresh-native inspection evidence.
Runner-side sing-box 1.11.4 and mihomo 1.19.32 profiles retain the supplied transport
settings and one-way credential fingerprints; only client labels/addresses change.
Secrets come from the existing shared Actions environment, never the workspace.

Infrastructure uses optional `spare_operation=inspect|create|destroy` and
`spare_target=americano|latte` on registered `terraform-deploy.yml`; empty spare
operation preserves all normal inputs and behavior. Destruction additionally needs
`expected_instance` matching the selected workspace's sole owned instance. Spare
operations cannot select serving nodes. They never modify Namecheap DNS; temporary
`name.IP.sslip.io` names allow hostname tests without repointing existing endpoints.
The unregistered native-infrastructure workflow need not be temporarily substituted.

Proxy `diagnose.yml` stage `validate-spare` accepts only Americano/Latte, expected IP,
selected credential environment, first runtime and the temporary validation hostname.
It tests fresh deployment, inspection/clients, unchanged deployment, invalid mode and
candidate rejection, recovery/reboot/log retention, switching/rollback, and peer
clients. Individual mutation stages require hostname/IP binding. A fresh native host
must additionally prove Docker absent; switched native hosts retain inactive packages.

Status: **completed on 2026-10-05; both spares destroyed**. Native 26.3.27 and
Docker 25.10.15 were validated with the supplied compatible transport profiles,
against IP and temporary hostname, using both pinned test clients. Neither serving
peer was redeployed. Existing Namecheap DNS was unchanged. No merge or release.

## Live acceptance and cleanup evidence

| Spare | Created identity (now retired) | Runtime evidence | Guarded cleanup |
| --- | --- | --- | --- |
| Americano | `lightsail-singapore-a-americano-20261005130801`, `18.136.230.110` | [fresh native inspection/lifecycle stages](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37315641328); [complete resumed Docker → native → Docker acceptance](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37325096175) | [destroyed](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37329320966) |
| Latte | `lightsail-singapore-c-latte-20261005130804`, `46.137.206.231` | [Docker → native → Docker stages](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37316417796); [client recheck](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37319934073), [rollback reboot](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37320104405), [final inspection](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37320136869) | [destroyed](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37320610039) |

Acceptance covers unchanged process/container and boot, rejection of invalid selector
and candidate while clients remain healthy, refusal without switch opt-in, explicit
switch/rollback, SIGKILL/reboot recovery, actual bounded-log rotation and preservation
of an unrelated container/network/config fixture. Each cleanup verifies absence of
the selected instance, static IP, key pair and matching snapshots, and deletes its
empty Terraform workspace. **No Americano/Latte validation resources remain.**

Post-cleanup serving peer transport checks: [run 37330086283](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37330086283), [run 37329634870](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37329634870).
At that checkpoint Flat White was `54.179.39.30`; Decaf was `52.74.81.140`.

## Findings and practical limits

Early attempts found two deployment defects: cleanup dereferenced a skipped
controller-download result, and root-only Docker candidate files were unreadable by
the official image's UID/GID 65532. Both are fixed with regression coverage. Native
remains root:xray 0640; Docker config is root:65532 0640 in a restricted directory.

Repeated stress exposed inherited journal-validation false positives. Retention
measures allocated blocks, not sparse logical lengths; rotation compares new archive
identities because old archives may be vacuumed at the same time. The
[read-only measurement](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37322665448)
showed 156 MiB logical size but only 92.2 MiB allocated, matching journalctl, with the
100/32/10 MB, seven-day, no-forwarding settings intact. No manual vacuum masks the test.

Recorded native binary SHA-256:
`8255dd939c34cf966cc91517b6324dd3c8d0bcf49ffac8beca049a38c46845ed`.
Recorded Docker image ID:
`sha256:9e479c59250703491b930da62dd6544bb5207b3372e1d8d6ba300b635b2e4990`.
Provisioned/running kernel remained `7.0.0-1012-aws`; deployment did not upgrade it.

Latte's main attempt and an Americano attempt stopped on intermittent mihomo hostname
requests after earlier successes. Successful follow-up runs are linked above. The
complete Americano run logged two recovered curl-35 TLS/network retries. The
client harness now logs bounded retries for transient network errors, requires every
sample to succeed, and fails persistent errors; HTTP/configuration failures are not
retried. The underlying cause of those one-off requests was not established. Runner
transport success does not establish iOS TUN/DNS or mobile ISP behavior. Native
25.10.15 remains reviewed and passes real-binary config checks; this spare sequence
uses native 26.3.27 and container 25.10.15.

Temporary PR triggers used during CLI/queue interruptions were removed after queueing;
none remain in the final tree. The normal infrastructure workflow was never replaced.
Future mutation/testing needs newly selected targets and authorized scope. Exact
selection/switch/rollback commands are in the [runtime contract](selectable-xray-runtime.md).

If a failed attempt has already installed the other runtime, `resume_spare=true`
allows re-selection on the same disposable host and skips the fresh-native Docker-absence
assertion. Retain the earlier fresh-host inspection evidence; resumed success does
not replace that proof. It still executes the complete runtime lifecycle/switch suite.

## Exact spare commands

```bash
# Registered infrastructure path; existing normal inputs still work unchanged.
gh workflow run terraform-deploy.yml --repo Jeonkwan/lightsail-proxy \
  --ref feature/selectable-xray-runtime -f workspace=americano \
  -f spare_operation=create -f spare_target=americano
# Repeat with workspace/target latte (zone C).
gh workflow run diagnose.yml --repo Jeonkwan/less-vision-reality \
  --ref feature/selectable-xray-runtime -f environment=flatwhite \
  -f target=americano -f stage=validate-spare -f deployment_mode=native \
  -f address=SPARE_IP -f validation_hostname=americano.SPARE_IP.sslip.io
# Latte starts with deployment_mode=docker. Use your selected credential environment.
gh workflow run terraform-deploy.yml --repo Jeonkwan/lightsail-proxy \
  --ref feature/selectable-xray-runtime -f workspace=americano \
  -f spare_operation=destroy -f spare_target=americano \
  -f expected_instance=EXACT_RECORDED_INSTANCE_NAME
```

Capture the created instance/IP from the guarded create run, never infer it from a
serving-node state file. Record sanitized acceptance/cleanup run links and recheck
serving clients after cleanup. Temporary test names do not create DNS resources;
existing Americano/Latte mokamaker.site DNS is preserved.

## Docker 26.3.27 alignment and Cream replacement

The subsequent owner instruction selects a new Cream for Docker-only deployment and
supplied authenticated sing-box/mihomo connection validation. Keep Cream if accepted,
then retire exact Flat White and clean its owned resources/DNS; preserve Decaf. Merge
this feature's existing PR chain after success, without new releases. This overrides
the previous spare-only scope for this task. Live results follow.

Controller validation of official `ghcr.io/xtls/xray-core:26.3.27` confirmed version,
ENTRYPOINT `/usr/local/bin/xray`, UID 65532 and actual config permission acceptance
(root:65532 0640 accepted; root 0600 rejected). Registry digest:
`sha256:592ec4d11f656db95598d01e76dbcc6e002d67360b96a5436500a938230f52c7`;
Linux/amd64 image ID:
`sha256:695c08e5627556d1286f43ae3aeb370679d27b969ba0d5bb3dfe288746a5dde9`.
Both deployment defaults now use 26.3.27, with separate version fields and explicit
reviewed 25.10.15 rollback options. Historical results above remain for Docker 25.10.15.

- [Preflight infrastructure inspection](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37344332315): Cream instance/IP/key/workspace/snapshots absent; both existing peers identified.
- [Cream creation](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37344496341): six owned basic-vm resources created; Flat White/Decaf identities and IPs preserved. Cream DNS now points to `18.136.58.134`.
- [Bootstrap readiness](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37344861362): provisioning reboot complete, bootstrap success and active `kho=off`.
- [Docker 26.3.27 deployment](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37345016593): Ansible succeeded with no failures; native role/artifact preparation skipped. Only the selected Docker prerequisites/runtime were installed.
- [Independent inspection and clients](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37345689320): running Xray 26.3.27 and official registry digest verified; dedicated nonroot image identity, config permissions, Compose ownership, inactive/disabled native unit, maintenance and bounded host/container log settings passed. Both supplied sing-box 1.11.4 and mihomo 1.19.32 profiles passed by IP and `cream.mokamaker.site`: 16 required HTTPS samples (HTTP 200/204), no recovered retry needed.
- [Flat White ownership inspection](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37345114517): workspace owned exactly `lightsail-singapore-a-flatwhite-20261005090040`; no snapshots present. Pre-replacement [Flat White](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37344757306) and [Decaf](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37344383565) client checks passed.

Xray 26.3.27 changed the CLI public-key label to `Password (PublicKey)`; credential
utilities now recognize it and retain old label compatibility. Parser failure/status
and secret-safe error regression checks pass. Final code checks cover both image
versions, native artifacts, selector isolation/invalid versions, both syntax modes,
Terraform/bootstrap, exact-identity/plan cleanup guards and whitespace. No cloud or
client credentials were exported to the development workspace.

This follow-up intentionally uses the owner's smaller acceptance gate. It did not
repeat SIGKILL, runtime switching, reboot or actual log-load rotation on Docker 26.3.27;
those tests remain historical Docker 25.10.15/selectable-runtime evidence. Effective
bounded-log settings were inspected. Runner success validates proxy transport, not
complete iOS TUN/DNS or a mobile ISP path. No new release/tag is published.

[Guarded Flat White retirement](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37345914302)
passed only after Cream acceptance. Exactly six owned resources were deleted, including
instance, public ports, key, static IP/attachment and DNS provisioner record. The helper
confirmed instance/IP/key/snapshots absent, deleted the empty `flatwhite` workspace,
parked `flatwhite.mokamaker.site` at `127.0.0.1`, and preserved Cream/Decaf identities
and static addresses. Shared credentials/environment/backend and unrelated resources
(`testing` IP/workspace/key and other legacy entries) were retained. Do not destroy
Cream: the owner explicitly elected to keep it after this validation.

Post-retirement [Cream clients](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37346231915)
and [Decaf clients](https://github.com/Jeonkwan/less-vision-reality/actions/runs/37346236555)
passed: 16 required IP/hostname HTTPS samples per node across both cores. Cream
needed no retries; Decaf recovered one transient network attempt under the existing
bounded retry policy. Its underlying cause is unestablished; all required samples passed.
[Final inventory](https://github.com/Jeonkwan/lightsail-proxy/actions/runs/37346240543)
confirmed only Cream/Decaf serving, Flat White workspace/key/instance absent and no
snapshots. Public DNS independently confirmed Cream `18.136.58.134`, Decaf
`52.74.81.140` and retired Flat White `127.0.0.1`.

Delivery follows the existing PR chain: infrastructure #24 → #23 → #22, proxy
#23 → #22 → #21, using merge commits and preserving source branches and immutable
release tags. To prevent its unrelated automatic `testing` apply/destroy cycle,
`terraform-deploy.yml` is temporarily disabled only around the final main merge and
then restored to active; its normal inputs and behavior remain unchanged. No new
release is requested. Native remains the default, now with Docker also pinned to
26.3.27. See the runtime guide for exact selection/switch/rollback commands.
