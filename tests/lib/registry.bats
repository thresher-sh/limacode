#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/registry.sh"
}

teardown() {
    _test_helper_teardown
}

@test "registry_validate passes for valid agent" {
    run registry_validate "${FIXTURES_DIR}/valid-agent.sh"
    [ "$status" -eq 0 ]
}

@test "registry_validate fails for missing file" {
    run registry_validate "${FIXTURES_DIR}/nonexistent.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "registry_validate fails for invalid agent (missing functions)" {
    run registry_validate "${FIXTURES_DIR}/invalid-agent.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"agent_cmd"* ]]
}

@test "registry_validate fails for bad name agent" {
    run registry_validate "${FIXTURES_DIR}/bad-name-agent.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not match"* ]]
}

@test "registry_validate rejects agent with eval" {
    local evil_agent="${TEST_TEMP_DIR}/evil-agent.sh"
    cat > "$evil_agent" <<'AGENT'
AGENT_NAME="evil-agent"
AGENT_DESCRIPTION="Evil agent"
agent_install() { eval "bad stuff"; }
agent_cmd() { echo "evil" "$@"; }
agent_cmd_interactive() { echo "evil"; }
AGENT
    run registry_validate "$evil_agent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"disallowed"* ]]
}

@test "registry_validate rejects agent name with uppercase" {
    local bad="${TEST_TEMP_DIR}/upper-agent.sh"
    cat > "$bad" <<'AGENT'
AGENT_NAME="Upper-Agent"
AGENT_DESCRIPTION="Bad name"
agent_install() { echo "install"; }
agent_cmd() { echo "run" "$@"; }
agent_cmd_interactive() { echo "run"; }
AGENT
    run registry_validate "$bad"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lowercase"* ]]
}

@test "registry_load sources valid agent and exposes functions" {
    registry_load "${FIXTURES_DIR}/valid-agent.sh"
    [ "$AGENT_NAME" = "valid-agent" ]
    result="$(agent_cmd --test)"
    [[ "$result" == *"valid-agent"* ]]
    [[ "$result" == *"--test"* ]]
}

@test "registry_list_agents lists all agents in registry dir" {
    run registry_list_agents "${LIMACODE_ROOT}/registry"
    [ "$status" -eq 0 ]
    # Will pass once we create the registry entries in Task 4
}
