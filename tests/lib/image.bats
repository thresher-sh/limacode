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

@test "image_local_path returns arch-specific path under LIMACODE_CONFIG_DIR" {
    result="$(image_local_path)"
    [[ "$result" == "${LIMACODE_CONFIG_DIR}"* ]]
    [[ "$result" == *".qcow2" ]]
    # Should contain arch
    [[ "$result" == *"arm64"* ]] || [[ "$result" == *"amd64"* ]]
}

@test "image_local_path includes architecture in filename" {
    result="$(image_local_path)"
    local arch
    arch="$(uname -m)"
    case "$arch" in
        aarch64|arm64) [[ "$result" == *"arm64"* ]] ;;
        x86_64|amd64)  [[ "$result" == *"amd64"* ]] ;;
    esac
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

@test "image_download fails gracefully when no release exists" {
    # Use a URL that will 404
    LIMACODE_RELEASE_URL="https://localhost:1/nonexistent"
    run image_download
    [ "$status" -ne 0 ]
    # Should not leave a temp file behind
    [[ ! -f "$(image_local_path).tmp" ]]
}

@test "image_resolve returns local image when it exists" {
    mkdir -p "$(dirname "$(image_local_path)")"
    echo "fake-image" > "$(image_local_path)"
    result="$(image_resolve 2>/dev/null)"
    [ "$result" = "$(image_local_path)" ]
}

@test "image_resolve tries download then build when no local image" {
    local call_log="${TEST_TEMP_DIR}/calls.log"
    touch "$call_log"

    # Override image_download and image_build
    image_download() {
        echo "download" >> "$call_log"
        # Simulate successful download
        mkdir -p "$(dirname "$(image_local_path)")"
        echo "downloaded-image" > "$(image_local_path)"
        return 0
    }
    export -f image_download

    result="$(image_resolve 2>/dev/null)"
    [ "$result" = "$(image_local_path)" ]

    # Should have called download
    grep -q "download" "$call_log"
    unset -f image_download
}

@test "image_resolve falls back to build when download fails" {
    local call_log="${TEST_TEMP_DIR}/calls.log"
    touch "$call_log"

    image_download() {
        echo "download" >> "$call_log"
        return 1
    }
    export -f image_download

    image_build() {
        echo "build" >> "$call_log"
        mkdir -p "$(dirname "$(image_local_path)")"
        echo "built-image" > "$(image_local_path)"
        return 0
    }
    export -f image_build

    result="$(image_resolve 2>/dev/null)"
    [ "$result" = "$(image_local_path)" ]

    # Should have called both download and build
    grep -q "download" "$call_log"
    grep -q "build" "$call_log"

    unset -f image_download
    unset -f image_build
}

@test "image_resolve returns 1 when all methods fail" {
    image_download() { return 1; }
    export -f image_download
    image_build() { return 1; }
    export -f image_build

    run image_resolve
    [ "$status" -ne 0 ]

    unset -f image_download
    unset -f image_build
}

@test "_image_arch returns valid architecture" {
    result="$(_image_arch)"
    [[ "$result" == "arm64" ]] || [[ "$result" == "amd64" ]]
}
