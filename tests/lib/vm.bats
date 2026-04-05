#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/vm.sh"
}

teardown() {
    _test_helper_teardown
}

@test "vm_instance_name generates correct format" {
    result="$(vm_instance_name "claude-code" "/Users/joe/project")"
    [[ "$result" =~ ^limacode-claude-code-[a-f0-9]{6}-[0-9]+$ ]]
}

@test "vm_instance_name uses consistent hash for same path" {
    result1="$(vm_instance_name "claude-code" "/Users/joe/project")"
    result2="$(vm_instance_name "claude-code" "/Users/joe/project")"
    hash1="$(echo "$result1" | rev | cut -d'-' -f2 | rev)"
    hash2="$(echo "$result2" | rev | cut -d'-' -f2 | rev)"
    [ "$hash1" = "$hash2" ]
}

@test "vm_instance_name uses different hash for different paths" {
    result1="$(vm_instance_name "claude-code" "/Users/joe/project-a")"
    result2="$(vm_instance_name "claude-code" "/Users/joe/project-b")"
    hash1="$(echo "$result1" | rev | cut -d'-' -f2 | rev)"
    hash2="$(echo "$result2" | rev | cut -d'-' -f2 | rev)"
    [ "$hash1" != "$hash2" ]
}

@test "vm_cwd_hash produces 6 character hex string" {
    result="$(vm_cwd_hash "/Users/joe/project")"
    [[ "$result" =~ ^[a-f0-9]{6}$ ]]
}

@test "vm_next_unique_int returns 1 when no instances exist" {
    limactl() { echo "[]"; }
    export -f limactl
    result="$(vm_next_unique_int "claude-code" "abc123")"
    [ "$result" = "1" ]
    unset -f limactl
}
