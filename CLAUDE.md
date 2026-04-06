# Claude

Master shell/bash script writer.

Never do git commands yourself.

Use BATS for testing.

## Debug and Tests

User will give you errors, and you will debug them. You will create new tests cases to cover these error cases. All errors should be covered by tests to you can automate making sure they are never re-introduced.

## Project Overview

Limacode is a CLI tool that sandboxes AI coding agents (Claude Code, OpenCode, Pi.dev) inside ephemeral Lima VMs. VMs are created fresh per session and destroyed on exit.

## Architecture

```
limacode.sh          — Main CLI entry point, dispatches commands
lib/config.sh        — Config management (~/.limacode/config, KEY=value)
lib/registry.sh      — Agent registry validation and loading
lib/yaml.sh          — Lima YAML generation (platform-aware)
lib/vm.sh            — VM lifecycle (create/start/stop/delete/shell)
lib/network.sh       — iptables script generation for --restrict-dns
lib/image.sh         — Base image build/export/checksum
registry/*.sh        — Agent definitions (claude-code, opencode, pi)
scripts/install.sh   — POSIX interactive installer (curl | sh)
scripts/provision.sh — Idempotent VM provisioning (runs inside VM)
```

## Conventions

- **Module namespacing**: functions prefixed by module name (`config_`, `registry_`, `yaml_`, `vm_`, `network_`, `image_`). Private functions prefixed with `_`.
- **Error handling**: `set -euo pipefail` everywhere. `log()` for info, `error()` for errors (both to stderr). Functions return 0/1; callers decide to exit.
- **Platform portability**: Bash 3.2+ compatible (no `readlink -f`). macOS uses VZ + virtiofs, Linux uses QEMU + 9p. Installer is POSIX sh.
- **Security**: Registry validation blocks `eval`, `source`, `. /`, `rm -rf /` before sourcing agent files. Env vars injected at runtime via subshell, never written to YAML.

## Running Tests

```bash
bats tests/              # All tests
bats tests/lib/yaml.bats # Single module
```

No Lima installation required for tests — VM functions are mocked.

## Linting

```bash
shellcheck limacode.sh lib/*.sh registry/*.sh scripts/provision.sh
shellcheck -s sh scripts/install.sh   # POSIX mode for installer
```

ShellCheck config in `.shellcheckrc` disables SC1090, SC1091, SC2034.

## Registry Agents

Agent files live in `registry/<name>.sh` and must export:
- `AGENT_NAME` (must match filename, `[a-z0-9-]+`)
- `AGENT_DESCRIPTION`
- `agent_install()` — runs inside VM during build
- `agent_cmd()` — returns headless command string (runs on host)
- `agent_cmd_interactive()` — returns interactive command string (runs on host)

## CI

Three-job pipeline in `.github/workflows/ci.yml`: lint → test (macOS + Ubuntu matrix) → release (on version tags).