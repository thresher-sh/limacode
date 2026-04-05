# limacode

Run AI coding agents in sandboxed Lima VMs with one command.

Limacode wraps [Lima VM](https://lima-vm.io) to give Claude Code, OpenCode, Pi.dev, and other terminal-based AI agents a real Linux virtual machine with full capabilities (docker, package managers, system tools) while keeping true kernel-level isolation from your host.

```bash
# Run Claude Code against your current project, sandboxed
limacode

# Run OpenCode instead
limacode --agent opencode

# Forward your API key and mount extra directories
limacode --env ANTHROPIC_API_KEY=sk-ant-xxx --adir libs:~/shared-libs
```

Your `$PWD` is mounted at `~/workspace/current` inside the VM. When the session ends, the VM is destroyed. Your code stays on the host.

## Install

```bash
curl -fsSL https://code.thresher.sh/install | sh
```

The installer checks prerequisites (Lima, jq), offers to install them, verifies SHA-256 checksums, and lets you choose whether to download the pre-built image now, later, or build it locally.

See [docs/quickstart.md](docs/quickstart.md) for detailed setup instructions.

## Supported Agents

| Agent | Flag | Description |
|-------|------|-------------|
| [Claude Code](https://claude.ai) | `--agent claude-code` (default) | Anthropic's terminal coding agent |
| [OpenCode](https://opencode.ai) | `--agent opencode` | Go-based agent by terminal.shop |
| [Pi.dev](https://github.com/nicholasgasior/pi-coding-agent) | `--agent pi` | Minimal, extensible agent by Mario Zechner |

More agents can be added via the [registry system](docs/registry.md).

## Commands

```
limacode [options]              Run agent against current directory (default)
limacode shell                  Attach to a running instance
limacode list                   Show running instances
limacode stop [id]              Stop and remove an instance
limacode build                  Build the base VM image locally
limacode update                 Rebuild base image with latest agents
limacode config <key> [value]   Get/set configuration
limacode version                Print version
limacode help                   Show help
```

## Options

```
--agent <name>              Agent to run (default: claude-code)
--adir <name>:<path>[,...]  Mount additional directories at ~/workspace/<name>
--restrict-dns <list>       Comma-separated domain allowlist
--env <KEY>=<VALUE>[,...]   Forward environment variables into the VM
--provision-script <path>   Custom provision script (for build)
--image <name>              Custom base image (for build)
```

All options can be persisted with `limacode config`:

```bash
limacode config agent opencode
limacode config env ANTHROPIC_API_KEY=sk-ant-xxx
limacode config adir github:~/github,data:/tmp/data
```

## How It Works

1. Limacode generates a Lima YAML config for your session
2. Creates an ephemeral VM with your project directory mounted
3. Starts the chosen agent inside the VM
4. When you exit, the VM is stopped and deleted

The agent runs in a full Linux VM with its own kernel, filesystem, and network stack. It can install packages, run docker, use system tools -- but it cannot touch anything on your host outside the mounted directories.

See [docs/architecture.md](docs/architecture.md) for the full technical breakdown.

## Documentation

- [Quick Start Guide](docs/quickstart.md) -- get running in 5 minutes
- [Architecture](docs/architecture.md) -- how limacode works under the hood
- [VM Lifecycle](docs/vm-lifecycle.md) -- instance naming, sessions, cleanup
- [Registry & Contributing Agents](docs/registry.md) -- add your own agents
- [CI/CD](docs/cicd.md) -- how the project is tested and released
- [Security](docs/SECURITY.md) -- what the sandbox protects and what it doesn't

## Platforms

macOS (VZ backend, virtiofs mounts) and Linux (QEMU backend, 9p mounts).

## License

MIT
