#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/config.sh"
}

teardown() {
    _test_helper_teardown
}

@test "config_get returns default when config file missing" {
    result="$(config_get agent)"
    [ "$result" = "claude-code" ]
}

@test "config_set creates config file and sets value" {
    config_set agent opencode
    result="$(config_get agent)"
    [ "$result" = "opencode" ]
}

@test "config_set overwrites existing value" {
    config_set agent opencode
    config_set agent pi
    result="$(config_get agent)"
    [ "$result" = "pi" ]
}

@test "config_get reads from existing config file" {
    cp "${FIXTURES_DIR}/sample-config" "${LIMACODE_CONFIG_DIR}/config"
    result="$(config_get agent)"
    [ "$result" = "opencode" ]
}

@test "config_get returns empty for unset key with no default" {
    result="$(config_get restrict-dns)"
    [ "$result" = "" ]
}

@test "config_get returns default for unknown key" {
    result="$(config_get nonexistent)"
    [ "$result" = "" ]
}

@test "config_list prints all config values" {
    config_set agent opencode
    config_set adir "github:~/github"
    run config_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent=opencode"* ]]
    [[ "$output" == *"adir=github:~/github"* ]]
}
