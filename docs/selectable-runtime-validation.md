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

Status: preparation in progress; no successful live-validation claim yet. Evidence
and exact resource cleanup results will be added after execution. Run commands and
runtime limitations remain in [runtime contract](selectable-xray-runtime.md).
