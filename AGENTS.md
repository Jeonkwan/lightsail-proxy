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
