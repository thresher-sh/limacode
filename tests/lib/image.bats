#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/yaml.sh"
    source "${LIMACODE_ROOT}/lib/image.sh"
}

teardown() {
    _test_helper_teardown
}

@test "image_local_path returns path under LIMACODE_CONFIG_DIR" {
    result="$(image_local_path)"
    [[ "$result" == "${LIMACODE_CONFIG_DIR}"* ]]
    [[ "$result" == *".qcow2"* ]] || [[ "$result" == *".img"* ]]
}

@test "image_exists returns false when no local image" {
    run image_exists
    [ "$status" -ne 0 ]
}

@test "image_exists returns true when local image present" {
    mkdir -p "$(dirname "$(image_local_path)")"
    touch "$(image_local_path)"
    run image_exists
    [ "$status" -eq 0 ]
}

@test "image_checksum_cmd works on current platform" {
    result="$(echo "test" | image_checksum_cmd)"
    [[ "$result" =~ ^[a-f0-9]{64} ]]
}
