# Selectable runtime spare validation

The owner selected **Americano** (Singapore zone A) and **Latte** (Singapore zone C)
for disposable validation, including reboot/failure/log-rotation tests, runtime
switching and destruction afterward. Flat White and Decaf remain serving peers.

Americano starts fresh in native mode; Latte starts fresh in Docker mode. Each
then switches to the other mode and rolls back using explicit switch opt-in.
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

Status: live acceptance is running on the two selected spares. Final acceptance
and exact resource cleanup results will be recorded after execution. Run commands and
runtime limitations remain in [runtime contract](selectable-xray-runtime.md).

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
