#!/usr/bin/env bats

load 'test_helper.sh'

setup() {
    _test_helper_setup
}

teardown() {
    _test_helper_teardown
}

@test "limacode version prints version string" {
    run bash "${LIMACODE_ROOT}/limacode.sh" version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^limacode\ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "limacode help prints usage" {
    run bash "${LIMACODE_ROOT}/limacode.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"limacode"* ]]
}

@test "limacode --help prints usage" {
    run bash "${LIMACODE_ROOT}/limacode.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "limacode unknown command exits with error" {
    run bash "${LIMACODE_ROOT}/limacode.sh" nonexistent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]]
}

@test "limacode config get returns default" {
    run bash "${LIMACODE_ROOT}/limacode.sh" config agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code"* ]]
}

@test "limacode config set and get roundtrip" {
    bash "${LIMACODE_ROOT}/limacode.sh" config agent opencode
    run bash "${LIMACODE_ROOT}/limacode.sh" config agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"opencode"* ]]
}

@test "limacode list works without lima running" {
    run bash "${LIMACODE_ROOT}/limacode.sh" list
    [ "$status" -eq 0 ]
}
