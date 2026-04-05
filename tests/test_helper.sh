#!/usr/bin/env bash
# Common test helper — sourced by all .bats files

LIMACODE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="${LIMACODE_ROOT}/tests/fixtures"

# Stub log/error functions used by lib modules (defined in limacode.sh)
log()   { printf '%s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

# Common setup/teardown — individual test files override these
# but should call _test_helper_setup/_test_helper_teardown
_test_helper_setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export LIMACODE_CONFIG_DIR="${TEST_TEMP_DIR}/.limacode"
    mkdir -p "${LIMACODE_CONFIG_DIR}"
}

_test_helper_teardown() {
    rm -rf "${TEST_TEMP_DIR}"
}

# Default setup/teardown (overridden by test files that need to source modules)
setup() {
    _test_helper_setup
}

teardown() {
    _test_helper_teardown
}
