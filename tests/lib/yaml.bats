#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    if [[ -f "${LIMACODE_ROOT}/lib/network.sh" ]]; then
        source "${LIMACODE_ROOT}/lib/network.sh"
    fi
    # Stub network_generate_iptables_script if not yet defined (lib/network.sh not yet implemented)
    if ! declare -f network_generate_iptables_script >/dev/null 2>&1; then
        network_generate_iptables_script() {
            local dns_list="$1"
            echo "#!/bin/bash"
            echo "# restrict-dns: ${dns_list}"
        }
    fi
    source "${LIMACODE_ROOT}/lib/yaml.sh"
}

teardown() {
    _test_helper_teardown
}

@test "yaml_generate produces valid YAML with required fields" {
    result="$(yaml_generate /tmp/testproject)"
    [[ "$result" == *"vmType:"* ]]
    [[ "$result" == *"cpus:"* ]]
    [[ "$result" == *"memory:"* ]]
    [[ "$result" == *"disk:"* ]]
    [[ "$result" == *"mounts:"* ]]
    [[ "$result" == *"ssh:"* ]]
}

@test "yaml_generate mounts PWD at workspace/current" {
    result="$(yaml_generate /tmp/testproject)"
    [[ "$result" == *"/tmp/testproject"* ]]
    [[ "$result" == *"workspace/current"* ]]
    [[ "$result" == *"writable: true"* ]]
}

@test "yaml_generate detects macOS platform" {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        skip "Not on macOS"
    fi
    result="$(yaml_generate /tmp/testproject)"
    [[ "$result" == *"vmType: vz"* ]]
    [[ "$result" == *"virtiofs"* ]]
}

@test "yaml_generate includes adir mounts" {
    result="$(yaml_generate /tmp/testproject "" "github:${HOME}/github,data:/tmp/data")"
    [[ "$result" == *"${HOME}/github"* ]]
    [[ "$result" == *"workspace/github"* ]]
    [[ "$result" == *"/tmp/data"* ]]
    [[ "$result" == *"workspace/data"* ]]
}

@test "yaml_generate rejects adir with reserved name current" {
    run yaml_generate /tmp/testproject "" "current:/tmp/bad"
    [ "$status" -ne 0 ]
    [[ "$output" == *"reserved"* ]]
}

@test "yaml_generate includes restrict-dns provisioning when set" {
    result="$(yaml_generate /tmp/testproject "" "" "api.anthropic.com,github.com")"
    [[ "$result" == *"provision:"* ]]
    [[ "$result" == *"api.anthropic.com"* ]]
}

@test "yaml_generate omits restrict-dns provisioning when empty" {
    result="$(yaml_generate /tmp/testproject)"
    [[ "$result" != *"iptables"* ]]
}

@test "yaml_generate uses correct arch for host platform" {
    result="$(yaml_generate /tmp/testproject)"
    local host_arch
    host_arch="$(uname -m)"
    case "$host_arch" in
        aarch64|arm64)
            [[ "$result" == *'arch: "aarch64"'* ]]
            [[ "$result" == *"arm64.img"* ]]
            ;;
        x86_64|amd64)
            [[ "$result" == *'arch: "x86_64"'* ]]
            [[ "$result" == *"amd64.img"* ]]
            ;;
    esac
}

@test "yaml_generate uses custom image without modifying arch in URL" {
    result="$(yaml_generate /tmp/testproject "file:///custom/image.qcow2")"
    [[ "$result" == *"file:///custom/image.qcow2"* ]]
}

@test "yaml_generate does not include env block" {
    result="$(yaml_generate /tmp/testproject)"
    [[ "$result" != *"env:"* ]]
}
