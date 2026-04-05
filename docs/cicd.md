# CI/CD

Limacode uses GitHub Actions for continuous integration, testing, and releases.

## Pipeline Overview

The CI workflow (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request. It has three jobs:

```
Push/PR to main
  |
  +-- lint (ShellCheck)
  +-- test (BATS on macOS + Ubuntu)
  |
  +-- release (on tag push only, after lint + test pass)
```

## Lint Job

Runs ShellCheck on all shell scripts:

```bash
shellcheck limacode.sh
shellcheck lib/*.sh
shellcheck registry/*.sh
shellcheck scripts/provision.sh
shellcheck -s sh scripts/install.sh    # POSIX mode for the installer
```

The project includes a `.shellcheckrc` that disables:
- `SC1090`, `SC1091` -- dynamic sourcing paths (unavoidable in the module system)
- `SC2034` -- unused variables (registry files declare optional `AGENT_DEPS`)

### Running locally

```bash
shellcheck limacode.sh lib/*.sh registry/*.sh scripts/provision.sh
shellcheck -s sh scripts/install.sh
```

## Test Job

Runs BATS unit tests on both **macOS** and **Ubuntu**:

```bash
bats tests/
```

This executes all `.bats` files across:
- `tests/limacode.bats` -- CLI argument parsing, subcommand dispatch, help/version
- `tests/lib/config.bats` -- config get/set/list, precedence, defaults
- `tests/lib/registry.bats` -- validation passes, failures, disallowed patterns
- `tests/lib/yaml.bats` -- YAML output, platform detection, adir mounts, restrict-dns
- `tests/lib/vm.bats` -- instance naming, CWD hashing, unique int generation
- `tests/lib/network.bats` -- iptables script generation
- `tests/lib/image.bats` -- image path, existence check, checksum tool

Tests do **not** require Lima to be installed. VM-related functions are tested via mocking (e.g., `export -f limactl` in tests) or by testing pure logic (hash generation, name formatting, YAML output strings).

### Running locally

```bash
# Run all tests
bats tests/

# Run a specific module's tests
bats tests/lib/config.bats

# Run with verbose output
bats --verbose-run tests/
```

### Integration tests

Integration tests that require a real Lima VM are gated behind an environment variable:

```bash
LIMACODE_INTEGRATION=1 bats tests/
```

These are not run in CI by default. They test:
- Full VM lifecycle (create, start, agent run, cleanup)
- Mount verification
- Network restriction enforcement

## Release Job

Triggered when a version tag is pushed (e.g., `v0.1.0`). Requires both lint and test to pass first.

### What it does

1. Checks out the code
2. Packages the CLI into a tarball:
   ```
   limacode/
     limacode.sh
     lib/
     registry/
     scripts/
   ```
3. Creates tarballs for four platforms (contents are identical since it's pure shell, but names match convention):
   - `limacode-v0.1.0-darwin-arm64.tar.gz`
   - `limacode-v0.1.0-darwin-amd64.tar.gz`
   - `limacode-v0.1.0-linux-amd64.tar.gz`
   - `limacode-v0.1.0-linux-arm64.tar.gz`
4. Generates SHA-256 checksums for each tarball
5. Creates a GitHub Release with all artifacts

### Cutting a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

The CI pipeline handles the rest. The release appears at `https://github.com/limacode/limacode/releases/tag/v0.1.0`.

### Base VM image

The base VM image (Ubuntu 24.04 with all agents pre-installed) is built separately and attached to the release. This image is what the installer downloads when you choose option A ("Download image now").

## Adding to CI

### Adding a new registry agent

When you add a new agent to `registry/`, CI automatically picks it up:
- ShellCheck lints it via `shellcheck registry/*.sh`
- BATS tests validate it via the `registry_list_agents` test

### Adding new tests

Create a `.bats` file in `tests/` or `tests/lib/`. The CI job runs `bats tests/` which discovers all test files recursively.

Follow the existing pattern:

```bash
#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/your-module.sh"
}

teardown() {
    _test_helper_teardown
}

@test "description of what you're testing" {
    result="$(your_function "input")"
    [[ "$result" == "expected" ]]
}
```
