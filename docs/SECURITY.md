# Security Considerations

Limacode runs AI coding agents inside Lima virtual machines, providing kernel-level isolation from your host machine. This document explains what the sandbox protects, what it doesn't, and how to make informed decisions about your security posture.

## VM Isolation Boundary

Each limacode session runs inside a full Linux virtual machine with its own kernel, filesystem, process tree, and network stack. This is stronger isolation than Docker containers or bubblewrap sandboxes, which share the host kernel.

**What is isolated:**
- Filesystem: the agent cannot access files outside of explicitly mounted directories
- Processes: the agent cannot see or interact with host processes
- Kernel: the agent runs on a separate Linux kernel, even on macOS hosts
- Users: the agent runs as a non-root user inside the VM

**What bridges the boundary:**
- Mounted directories (see below)
- Forwarded environment variables
- SSH agent forwarding
- Network access

## Mounted Directories

Your current working directory (`$PWD`) is mounted writable inside the VM at `~/workspace/current`. Any additional directories added with `--adir` are also mounted writable.

**The agent has full read, write, and delete access to all mounted directories.** Only mount directories you are comfortable giving the agent unrestricted access to.

- Do not mount your entire home directory writable
- Do not mount directories containing credentials, SSH keys, or other secrets
- The reserved name `current` cannot be used with `--adir`

## Environment Variables

Only variables explicitly forwarded with `--env KEY=VALUE` enter the VM. There is no automatic forwarding of host environment variables.

Variables are injected at runtime via Lima's `--preserve-env` mechanism and are **never written to disk** in the Lima YAML configuration file.

However, once inside the VM, the agent process and any child processes it spawns can read all forwarded variables. If you forward an API key, any code the agent runs inside the VM can access it.

**Recommendations:**
- Only forward the minimum required variables
- Use scoped/limited API keys when possible
- Rotate keys if you suspect they have been exposed

## SSH Agent Forwarding

By default, Lima forwards your host SSH agent into the VM. This allows the agent to perform git operations (clone, push, pull) using your SSH keys.

**Important:** The agent **cannot extract your private keys** from the SSH agent. It can only request signatures for the duration of the session. However, while the session is active, the agent can use your SSH identity to authenticate to any service your keys grant access to (e.g., push to your GitHub repositories).

A future version of limacode may add a `--no-ssh-agent` flag for users who require stricter isolation.

## Network Access

By default, the VM has **full internet access**. The agent can make HTTP requests, download packages, and communicate with any external service.

### `--restrict-dns` Limitations

The `--restrict-dns` option provides IP-level network filtering using iptables inside the VM:

- Domains are resolved to IP addresses, and only those IPs are allowed
- DNS resolution itself is permitted (the VM can look up any domain, it just cannot connect to unauthorized IPs)
- CDN IPs may serve multiple domains — allowing `cdn.example.com` may inadvertently allow access to other sites on the same CDN
- IP addresses for domains can change; a background cron job re-resolves every 5 minutes, but there is a window where new IPs are not yet allowed or old IPs are still allowed
- This is **not equivalent to a domain-level firewall** — for robust domain filtering, a proxy-based approach (planned for a future version) is recommended

**Private network ranges** (`192.168.0.0/16`, `10.0.0.0/8`) are always allowed, as they are required for Lima's internal SSH communication between host and guest.

## Pre-built Images

Limacode publishes pre-built VM images on GitHub releases. Each image includes SHA-256 checksums that the installer verifies before use.

If you do not trust the hosted images:
- Use `limacode build` to build the image locally from the `scripts/provision.sh` script
- Review `scripts/provision.sh` to see exactly what software is installed
- Choose option C during installation to build locally

## Registry Trust

Agent definitions in the `registry/` directory are shell scripts. While limacode validates them before use (checking for disallowed patterns and required contract compliance), this validation is not a comprehensive security audit.

**For community-contributed agents:** Review the agent's `.sh` file before using it. The `agent_install()` function runs inside the VM during image builds, and `agent_cmd()`/`agent_cmd_interactive()` define what commands execute in the VM.

## Recommendations

For general use:
- Forward only the API keys you need with `--env`
- Only mount the project directory you're working on

For sensitive projects:
- Use `--restrict-dns` to limit network access to necessary domains
- Build your own image with `limacode build`
- Review the agent registry file before first use
