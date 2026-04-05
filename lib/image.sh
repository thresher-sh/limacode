#!/usr/bin/env bash
# Image module — build and manage base VM images
# NOTE: image_build() depends on _yaml_detect_platform/_yaml_detect_mount_type from lib/yaml.sh.
# When used via limacode.sh, yaml.sh is sourced first. For standalone use, source yaml.sh before image.sh.
# LIMACODE_ROOT must be set by the caller (limacode.sh sets it, test_helper.sh sets it).

LIMACODE_CONFIG_DIR="${LIMACODE_CONFIG_DIR:-${HOME}/.limacode}"
LIMACODE_IMAGE_NAME="limacode-base.qcow2"

image_local_path() {
    echo "${LIMACODE_CONFIG_DIR}/images/${LIMACODE_IMAGE_NAME}"
}

image_exists() {
    [[ -f "$(image_local_path)" ]]
}

image_checksum_cmd() {
    if command -v sha256sum &>/dev/null; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 | cut -d' ' -f1
    else
        echo "ERROR: No sha256sum or shasum found" >&2
        return 1
    fi
}

image_verify_checksum() {
    local file="$1"
    local expected="$2"
    local actual
    actual="$(image_checksum_cmd < "$file")"
    [[ "$actual" == "$expected" ]]
}

image_build() {
    local provision_script="${1:-${LIMACODE_ROOT}/scripts/provision.sh}"
    local base_image="${2:-}"
    local temp_instance="limacode-build-$$"

    log "Building limacode base image..."
    log "This may take 5-10 minutes."

    local build_yaml
    build_yaml="$(mktemp /tmp/limacode-build-XXXXXX.yaml)"

    cat > "$build_yaml" <<YAML
vmType: $(_yaml_detect_platform)
arch: default
cpus: 4
memory: "4GiB"
disk: "50GiB"

images:
- location: "${base_image:-https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img}"
  arch: "x86_64"
- location: "${base_image:-https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img}"
  arch: "aarch64"

mountType: "$(_yaml_detect_mount_type)"

mounts:
- location: "${LIMACODE_ROOT}"
  writable: false

ssh:
  localPort: 0
  forwardAgent: false

containerd:
  system: false
  user: false

video:
  display: "none"
YAML

    if ! limactl create --name="$temp_instance" --tty=false "$build_yaml"; then
        rm -f "$build_yaml"
        error "Failed to create build VM"
        return 1
    fi
    rm -f "$build_yaml"

    if ! limactl start --tty=false --timeout=15m "$temp_instance"; then
        limactl delete -f "$temp_instance" 2>/dev/null
        error "Failed to start build VM"
        return 1
    fi

    log "Running provision script..."
    if ! limactl shell "$temp_instance" -- bash < "$provision_script"; then
        limactl stop "$temp_instance" 2>/dev/null
        limactl delete -f "$temp_instance" 2>/dev/null
        error "Provisioning failed"
        return 1
    fi

    limactl stop "$temp_instance"

    local image_dir
    image_dir="$(dirname "$(image_local_path)")"
    mkdir -p "$image_dir"

    log "Exporting image..."
    local lima_disk="${HOME}/.lima/${temp_instance}/diffdisk"
    if [[ -f "$lima_disk" ]]; then
        cp "$lima_disk" "$(image_local_path)"
    fi

    limactl delete -f "$temp_instance" 2>/dev/null

    log "Base image built: $(image_local_path)"
}

image_update() {
    log "Updating limacode base image with latest agents..."
    image_build "$@"
    log "Update complete. New instances will use the updated image."
}
