# Agent entry point

Before development, read [development environment](docs/development.md) for
required tools, versions, setup, credential boundaries and local validation.
Read [disposable VM strategy](docs/disposable-proxy-vms.md) before changing
bootstrap, maintenance policy or deployment behavior.

Work on a feature branch and run the repository-specific checks in the development
guide. Live deployment/testing needs an explicitly selected target and authorized
scope; cloning and setup do not authorize apply, destroy, reboot or redeployment.
Preserve other running proxy nodes. Use GitHub Actions credentials rather than
requesting/exporting secrets into the workspace. Never commit credentials or state.

Product changes require validation before merging and explicit user confirmation
for merge. Keep the development guide synchronized when dependencies change.

For selectable runtime work, read [runtime contract](docs/selectable-xray-runtime.md)
and [spare validation](docs/selectable-runtime-validation.md) before changing
runtime selection, diagnostics or Actions. Keep native 26.3.27 / reviewed 25.10.15
and Docker 26.3.27 (explicit reviewed 25.10.15 rollback) pinned; verify candidates before switching, scope cleanup by
ownership, and preserve unchanged runtimes. Agent and human runbooks must stay in sync.

On 2026-10-05 the owner-selected Americano and Latte validation completed; both
spares and their owned resources/workspaces were destroyed after validation. That scope excludes serving Flat White
and Decaf. Use isolated spare workspaces and the guarded spare Actions path; verify
exact ownership before destruction and confirm instance/static IP/key/snapshots and
empty workspace cleanup. Keep existing DNS endpoints unless explicitly selected for
repointing. Credentials stay in GitHub Actions. This authorization is task-specific,
not standing permission for future cloud mutations. Merge/releases still require
separate owner instructions.

The owner subsequently authorized Docker-only 26.3.27 validation on a new Cream.
Acceptance is successful deployment and authenticated supplied sing-box/mihomo
connections against IP and hostname; no additional lifecycle/soak suite is required
for this version alignment. If accepted, keep Cream, destroy only the exact recorded
Flat White instance and its owned IP/key/snapshots/workspace, and park its DNS.
Preserve Decaf and shared credentials/backends. Merge this task's PR chain after
validation; do not publish releases. This supersedes the previous task's scope,
not standing authorization for later operations. Record final identities and evidence
in docs/selectable-runtime-validation.md and keep human/agent instructions aligned.

Current deployment record for this completed replacement: Cream
`lightsail-singapore-a-cream-20261005165610`, `18.136.58.134`, Docker 26.3.27;
Decaf `lightsail-singapore-c-decaf-20261005103556`, `52.74.81.140`, native 26.3.27.
Flat White `lightsail-singapore-a-flatwhite-20261005090040` is retired; its owned
resources/workspace are removed and DNS is parked at 127.0.0.1. Retain the shared
Actions environment/secrets despite its historical name `flatwhite`. Any later
cloud mutation needs a new owner-selected scope; these records are evidence, not
permission to redeploy serving nodes or repeat retirement. See the validation record.
