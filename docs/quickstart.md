# Quick Start Guide

Get limacode running in 5 minutes.

## Prerequisites

- **macOS 13.5+** or **Linux** (Ubuntu 22.04+, Fedora 38+, Arch)
- An API key for your chosen agent (e.g., `ANTHROPIC_API_KEY` for Claude Code)

The installer handles everything else (Lima, jq, QEMU on Linux).

## Install

```bash
curl -fsSL https://code.thresher.sh/install | sh
```

The installer will:
1. Detect your platform and shell
2. Check for prerequisites (Lima, jq, curl)
3. Offer to install anything missing
4. Download the limacode CLI with SHA-256 verification
5. Ask if you want to download the base VM image now or later

After install, restart your shell or run:
```bash
source ~/.zshrc    # or ~/.bashrc
```

### Non-interactive install (CI/automation)

```bash
curl -fsSL https://code.thresher.sh/install | sh -s -- --yes --image=download-now
```

### Homebrew (macOS)

```bash
brew install limacode/tap/limacode
```

## First Run

Navigate to any project directory and run:

```bash
cd ~/my-project
limacode --env ANTHROPIC_API_KEY=sk-ant-xxx
```

On first run, if you haven't downloaded the base image yet, limacode will use a stock Ubuntu 24.04 cloud image and provision it (this takes 5-10 minutes the first time). Subsequent runs are fast.

To skip the first-run wait, build or download the image in advance:

```bash
limacode build     # Build locally (~5-10 min)
```

## Set a Default Agent

```bash
limacode config agent claude-code
```

Now `limacode` without `--agent` always runs Claude Code.

## Persist Your API Key

```bash
limacode config env ANTHROPIC_API_KEY=sk-ant-xxx
```

Now you don't need `--env` every time. The key is stored in `~/.limacode/config` (plain text -- treat this file as sensitive).

## Switch Agents

```bash
limacode --agent opencode --env OPENAI_API_KEY=sk-xxx
limacode --agent pi --env ANTHROPIC_API_KEY=sk-ant-xxx
```

## Mount Extra Directories

```bash
limacode --adir shared-libs:~/shared-libs
```

This mounts `~/shared-libs` at `~/workspace/shared-libs` inside the VM. You can mount multiple:

```bash
limacode --adir libs:~/libs,data:/tmp/data
```

## Manage Running Instances

```bash
limacode list               # See what's running
limacode shell              # Attach to a running instance
limacode stop               # Stop and remove an instance
```

If multiple instances are running, `shell` and `stop` show a picker.

## Restrict Network Access

```bash
limacode --restrict-dns api.anthropic.com,github.com,registry.npmjs.org
```

Only the listed domains (resolved to IPs) will be reachable from inside the VM. See [Security](SECURITY.md) for limitations of this approach.

## Shell Aliases

Add to your `.zshrc` for quick access:

```bash
alias cc="limacode --agent claude-code"
alias oc="limacode --agent opencode"
alias pi="limacode --agent pi"
```

## Next Steps

- [Architecture](architecture.md) -- understand how limacode works
- [Registry](registry.md) -- add your own agents
- [Security](SECURITY.md) -- understand the isolation model
