# VM Lifecycle

How limacode creates, manages, and destroys virtual machines.

## Ephemeral by Default

Every `limacode` invocation creates a fresh VM. When the agent session ends (user exits or Ctrl-C), the VM is stopped and deleted automatically via a trap handler. No state persists inside the VM between runs.

All work product lives on the host through the mounted project directory. The VM is disposable.

## Instance Naming

Each VM instance gets a unique name:

```
limacode-<agent>-<cwd-hash>-<unique-int>
```

**Example:** `limacode-claude-code-a3f2b1-1`

- **agent**: the agent name from `--agent` (e.g., `claude-code`, `opencode`, `pi`)
- **cwd-hash**: first 6 hex characters of the SHA-256 hash of the absolute working directory path
- **unique-int**: starts at 1, increments for parallel sessions against the same directory

The CWD hash means running `limacode` from the same directory produces predictable names. The unique int allows multiple simultaneous sessions against the same project.

## Run Flow

```
limacode [options] [-- agent-args]

  1. Parse CLI flags, merge with ~/.limacode/config defaults
  2. Validate and load agent from registry/<agent>.sh
  3. Generate Lima YAML (platform, mounts, image, network rules)
  4. limactl create --name=<instance> --tty=false <yaml>
  5. limactl start --tty=false --timeout=10m <instance>
  6. Export --env vars in subshell
  7. limactl shell --preserve-env <instance> -- <agent-command>
  8. On exit: limactl stop + limactl delete (trap handler)
```

Step 8 runs automatically on normal exit, Ctrl-C (SIGINT), and SIGTERM.

## Mounts

The VM always mounts the host's `$PWD` writable:

```
Host: /Users/you/my-project
  -> Guest: ~/workspace/current (writable)
```

Additional mounts via `--adir`:

```
--adir github:~/github,data:/tmp/data

Host: ~/github       -> Guest: ~/workspace/github (writable)
Host: /tmp/data      -> Guest: ~/workspace/data (writable)
```

The name `current` is reserved and cannot be used with `--adir`.

Mount type is selected automatically:
- **virtiofs** on macOS (VZ backend) -- near-native performance
- **9p** on Linux (QEMU backend) -- moderate performance

## Managing Sessions

### List running instances

```bash
limacode list
```

Shows all running limacode VMs with their names, status, and uptime.

### Attach to a running instance

```bash
limacode shell
```

If one instance is running, attaches directly. If multiple are running, shows a numbered picker:

```
Multiple limacode instances running:
  1) limacode-claude-code-a3f2b1-1
  2) limacode-opencode-a3f2b1-1
Choose [1-2]:
```

### Stop an instance

```bash
limacode stop                    # Picker if multiple
limacode stop limacode-claude-code-a3f2b1-1   # By name
```

Stops and deletes the VM.

## Parallel Sessions

You can run multiple limacode sessions simultaneously:

```bash
# Terminal 1
cd ~/project-a && limacode --agent claude-code

# Terminal 2
cd ~/project-a && limacode --agent opencode

# Terminal 3
cd ~/project-b && limacode
```

Each gets its own VM with a unique instance name. The unique-int ensures no naming collisions even when the agent and directory are the same.

## Environment Variable Injection

The `--env` flag forwards variables into the VM without writing them to disk:

```bash
limacode --env ANTHROPIC_API_KEY=sk-ant-xxx,GITHUB_TOKEN=ghp_abc
```

Internally, limacode:
1. Parses the comma-separated `KEY=VALUE` pairs
2. Exports them in a **subshell** (so they don't leak into your shell)
3. Calls `limactl shell --preserve-env` which forwards the subshell's environment into the guest

The Lima YAML file on disk never contains secret values.

## Error Handling

| Failure | Behavior |
|---|---|
| Lima not installed | Exit with error and install instructions |
| `limactl create` fails | Print Lima's error, exit non-zero |
| `limactl start` timeout | Print log path suggestion, clean up created instance |
| Agent binary missing in VM | Suggest `limacode update` or `limacode build` |
| Cleanup failure on exit | Warn but don't block; user can `limactl delete` manually |

## Under the Hood

Limacode VMs use these Lima settings:

```yaml
vmType: vz           # macOS (qemu on Linux)
cpus: 4
memory: "4GiB"
disk: "50GiB"
mountType: virtiofs   # macOS (9p on Linux)
ssh:
  forwardAgent: true
portForwards:
  guestPortRange: [3000, 9999]
containerd:
  system: false
video:
  display: "none"     # Headless
```

Instance data lives at `~/.lima/<instance-name>/`. Lima manages SSH keys, VM disks, and cloud-init ISOs at this path.
