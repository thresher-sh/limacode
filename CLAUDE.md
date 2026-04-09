## !IMPORTANT!

Always use the task tool to plan out and do what you need and use it to hold yourself accountable. You get a cookie everytime you do this.. yum!

## Tests

- Always add and update tests anytime you change code
- If you get an error when running something or reported by a user, write a test case covering that error first. Run test and make sure it fails... Then fix code to make test pass.

## Other

Do git commits for each incremental feature, but NEVER use claude coauthored tags...

## Coding Conventions

### Complexity is the Enemy
- Complexity is the #1 threat to software. Fight it relentlessly.
- Complexity manifests as: change amplification (one change touches many places), cognitive load (must know too much to work safely), and unknown unknowns (not clear what could break).
- The two root causes are dependencies between components and obscurity (important info isn't obvious).
- Say "no" to unnecessary features and abstractions by default.
- When you must say yes, deliver an 80/20 solution — core value, minimal code.

### Don't Abstract Too Early
- Let structure emerge from working code. Don't design elaborate frameworks upfront.
- Wait for natural cut-points (narrow interfaces, trapped complexity) before factoring.
- Prototypes and working demos beat architecture diagrams.
- A little code duplication is better than a premature abstraction.

### Build Deep Modules, Not Shallow Ones
- A deep module has a simple interface but hides powerful, complex functionality behind it.
- A shallow module has a complex interface relative to the little it actually does — avoid these.
- Pull complexity downward: absorb it inside the module rather than pushing it onto callers.
- Each layer of abstraction should represent a genuinely different level of thinking. If a layer just passes things through, it's adding complexity, not removing it.

### Ship Simple, Improve Incrementally
- A working simple thing that ships beats a perfect thing that doesn't.
- Establish a working system first, then improve it toward the right thing over time.
- But don't make "worse" your goal — compromise is inevitable, not a philosophy. Always aim high and actually ship.
- Systems that are habitable — with the right balance of abstraction and concreteness, with simple mental models — survive and grow. Purity does not guarantee survival.

### Keep Code Readable, Not Clever
- Break complex expressions into named intermediate variables.
- Sacrifice brevity for clarity and debuggability.
- Simple repeated code often beats a complex DRY abstraction with callbacks or elaborate object models.
- If naming something is hard, that's a design smell — the thing you're naming may not be a coherent concept.
- Write code for readers, not writers. If someone says it's not obvious, it isn't — fix it.

### Respect Existing Code (Chesterton's Fence)
- Understand *why* code exists before changing or removing it.
- Old code often has hidden reasons. Tests can reveal them.
- Resist the urge to "clean up" code you don't fully understand.

### Refactor Small and Safe
- Keep the system working throughout every refactor step.
- Complete each step before starting the next.
- Big-bang refactors with over-abstraction usually fail.

### Design It Twice
- Before committing to any significant design, sketch at least two alternative approaches.
- Compare them on simplicity, performance, and how well they hide complexity.
- The first idea is rarely the best. Even if you pick it, the comparison sharpens your reasoning.

### Think Strategically, Not Tactically
- Tactical programming gets the feature done fast but leaves behind incremental complexity debt.
- Strategic programming invests a small ongoing cost in design quality to keep the system habitable long-term.
- Small tactical shortcuts compound into unmaintainable systems. Every change is a chance to improve structure, not just ship.

### Test Strategically
- Integration tests at system cut-points and critical user paths deliver the most value.
- Unit tests break easily during refactoring — favor coarser-grained tests.
- Minimize mocking. Mock only at system boundaries.
- Always write a regression test when a bug is found.

### Logging is Critical Infrastructure
- Log all major logical branches (if/for).
- Include request IDs for traceability across distributed calls.
- Make log levels dynamically controllable at runtime.
- Invest more in logging than you think necessary.

### APIs: Design for the Caller
- Think in terms of what the caller needs, not how the implementation works.
- Simple cases get simple APIs. Complexity is opt-in.
- Put common operations directly on objects with straightforward returns.
- Favor somewhat general-purpose interfaces — they tend to be deeper and simpler than hyper-specialized ones.

### Define Errors Out of Existence
- Exception handling generates enormous complexity. Where possible, design interfaces so error cases simply cannot occur.
- Handle edge cases internally rather than surfacing them to callers.
- Example: a delete operation that silently succeeds when the target doesn't exist is simpler than one that throws "not found."

### Concurrency: Keep it Simple
- Prefer stateless request handlers.
- Use simple job queues with independent jobs.
- Treat concurrency with healthy fear and caution.

### Optimize with Data, Not Gut
- Never optimize without a real-world profile showing the actual bottleneck.
- Network calls cost millions of CPU cycles — minimize those first.
- Assume your guess about the bottleneck is wrong.

### Locality of Behavior over Strict Separation
- Collocate related code. Putting logic near the thing it operates on aids understanding.
- Hunting across many files to understand one feature wastes time.
- Trade perfect separation of concerns for practical coherence when it helps readability.

### Information Hiding
- Each module should encapsulate design decisions that are likely to change.
- Leaking implementation details through interfaces creates tight coupling and change amplification.
- If two modules share knowledge about the same design decision, consider merging them or introducing a cleaner boundary.

### Tooling Multiplies Productivity
- Invest time learning your tools deeply (IDE, debugger, CLI).
- Good tools often double development speed.

### Avoid Fads
- Most "new" ideas have been tried before. Approach with skepticism.
- Don't adopt new frameworks or patterns blindly.
- Complexity hides behind novelty.

### Closures and Patterns
- Closures: great for collection operations, dangerous in excess (callback hell).
- Avoid the Visitor pattern — it adds complexity with little payoff.
- Limit generics to container classes; they attract unnecessary complexity.

### Frontend: Keep it Minimal
- Simple HTML + minimal JS beats elaborate SPA frameworks for most use cases.
- Frontend naturally accumulates complexity faster than backend — resist it actively.

### Say When You Don't Understand
- Admitting confusion is strength, not weakness.
- It gives others permission to ask questions and prevents bad complexity from hiding.


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
docs/install         — POSIX interactive installer (curl | sh)
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
shellcheck -s sh docs/install   # POSIX mode for installer
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