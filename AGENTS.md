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
and Docker 25.10.15 pinned; verify candidates before switching, scope cleanup by
ownership, and preserve unchanged runtimes. Agent and human runbooks must stay in sync.

On 2026-10-05 the owner-selected Americano and Latte validation completed; both
spares and their owned resources/workspaces were destroyed after validation. That scope excludes serving Flat White
and Decaf. Use isolated spare workspaces and the guarded spare Actions path; verify
exact ownership before destruction and confirm instance/static IP/key/snapshots and
empty workspace cleanup. Keep existing DNS endpoints unless explicitly selected for
repointing. Credentials stay in GitHub Actions. This authorization is task-specific,
not standing permission for future cloud mutations. Merge/releases still require
separate owner instructions.
