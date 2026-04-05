# Registry System

The registry is how limacode knows about agents. Each agent is a shell file in the `registry/` directory that defines how to install and run it.

## Built-in Agents

Limacode ships with three agents:

| File | Agent | Install Method |
|------|-------|---------------|
| `registry/claude-code.sh` | Claude Code | Native binary (`curl \| bash`) |
| `registry/opencode.sh` | OpenCode | Go binary (`curl \| bash`) |
| `registry/pi.sh` | Pi.dev | npm package |

## Agent File Format

Each agent file must define two variables and three functions:

```bash
#!/usr/bin/env bash

# Required variables
AGENT_NAME="my-agent"                    # Must match filename (my-agent.sh)
AGENT_DESCRIPTION="Short description"    # Shown in limacode help

# Required functions
agent_install() {
    # Runs INSIDE the VM during image build and limacode update.
    # Install or update the agent binary/package.
    curl -fsSL https://example.com/install.sh | bash
}

agent_cmd() {
    # Runs on the HOST. Returns the command to execute in headless mode.
    # $@ contains user-provided arguments.
    echo "my-agent" "--headless" "$@"
}

agent_cmd_interactive() {
    # Runs on the HOST. Returns the command for interactive mode.
    echo "my-agent"
}

# Optional
AGENT_DEPS=""              # Extra apt packages needed beyond base image

agent_env_hint() {
    # Printed when the agent needs auth setup help.
    echo "Hint: forward your API key with --env MY_API_KEY=<key>"
}
```

### How It Works

1. `agent_cmd()` and `agent_cmd_interactive()` run on the **host**. They output a command string.
2. Limacode passes that command to `limactl shell <instance> -- <command>`, which executes it inside the VM.
3. `agent_install()` is the exception -- it runs **inside the VM** during `limacode build` and `limacode update`.

This separation means the registry file itself is never sourced inside the VM.

## Naming Rules

- `AGENT_NAME` must contain only lowercase letters, numbers, and hyphens: `[a-z0-9-]`
- `AGENT_NAME` must match the filename (e.g., `my-agent.sh` must declare `AGENT_NAME="my-agent"`)
- The name `current` is reserved and cannot be used

## Validation

Before sourcing any registry file, limacode validates it:

**Static checks (before sourcing):**
- File exists and is readable
- Contains required variable declarations (`AGENT_NAME`, `AGENT_DESCRIPTION`)
- Contains required function definitions (`agent_install`, `agent_cmd`, `agent_cmd_interactive`)
- No disallowed patterns in non-comment lines (`eval`, `rm -rf /`, `source`, `. /`)

**Post-source checks (in a sandboxed subshell):**
- `AGENT_NAME` matches the filename
- `AGENT_NAME` matches the `[a-z0-9-]` format
- Required functions are callable

**CI checks (not at runtime):**
- ShellCheck passes on all registry files

If validation fails, limacode prints the specific error and refuses to load the agent.

## Contributing a New Agent

### 1. Create the agent file

```bash
# registry/my-agent.sh
#!/usr/bin/env bash
AGENT_NAME="my-agent"
AGENT_DESCRIPTION="My awesome coding agent"
AGENT_DEPS=""

agent_install() {
    # Whatever installs your agent in Ubuntu 24.04
    npm install -g my-agent-package
}

agent_cmd() {
    echo "my-agent" "--print" "$@"
}

agent_cmd_interactive() {
    echo "my-agent"
}

agent_env_hint() {
    echo "Hint: set --env MY_AGENT_API_KEY=<key>"
}
```

### 2. Test it locally

```bash
# Validate the file
bats tests/lib/registry.bats

# Check with ShellCheck
shellcheck registry/my-agent.sh

# Test with limacode (requires Lima installed)
limacode --agent my-agent --env MY_AGENT_API_KEY=xxx
```

### 3. Update the provision script

Add your agent's install command to `scripts/provision.sh` so it gets included in the base image:

```bash
# --- My Agent ---
echo "Installing My Agent..."
npm install -g my-agent-package || true
```

The `|| true` ensures provisioning continues even if one agent's install fails.

### 4. Add any system dependencies

If your agent needs packages beyond the base image (Node.js, Go, and Python are already included), either:
- Add them to `scripts/provision.sh`
- Set `AGENT_DEPS="package1 package2"` in your registry file (these get installed during build)

### 5. Submit a PR

Your PR should include:
- `registry/<agent-name>.sh` -- the agent definition
- Update to `scripts/provision.sh` -- agent install step
- All existing tests must still pass: `bats tests/`
- ShellCheck must pass: `shellcheck registry/<agent-name>.sh`

## Disallowed Patterns

The following patterns are blocked in registry files (checked against non-comment lines):

| Pattern | Reason |
|---------|--------|
| `eval` | Arbitrary code execution risk |
| `rm -rf /` | Destructive filesystem operation |
| `source` | Sourcing external files could bypass validation |
| `. /` | Same as source -- dot-sourcing external files |

If your agent legitimately needs one of these, open an issue to discuss alternatives.

## Agent Requirements

For an agent to work with limacode, it needs:

1. **Headless mode**: a flag to run non-interactively with a prompt (e.g., `-p "prompt"`, `exec "prompt"`)
2. **Interactive mode**: the ability to run as a TUI or REPL
3. **Linux support**: it must run on Ubuntu 24.04 (x86_64 or aarch64)
4. **Auth via env vars**: API keys or tokens passed as environment variables

Agents that require a browser for OAuth or have no headless mode are not currently supported.
