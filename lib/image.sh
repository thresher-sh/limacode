#!/usr/bin/env bash
# Image module — build, download, and manage base VM images
# NOTE: image_build() depends on _yaml_detect_platform/_yaml_detect_mount_type from lib/yaml.sh.
# When used via limacode.sh, yaml.sh is sourced first. For standalone use, source yaml.sh before image.sh.
# LIMACODE_ROOT must be set by the caller (limacode.sh sets it, test_helper.sh sets it).

LIMACODE_CONFIG_DIR="${LIMACODE_CONFIG_DIR:-${HOME}/.limacode}"
LIMACODE_RELEASE_URL="${LIMACODE_RELEASE_URL:-https://github.com/thresher-sh/limacode/releases/latest/download}"

_image_arch() {
    local host_arch
    host_arch="$(uname -m)"
    case "$host_arch" in
        aarch64|arm64) echo "arm64" ;;
        x86_64|amd64)  echo "amd64" ;;
        *)
            echo "ERROR: Unsupported architecture: ${host_arch}" >&2
            return 1
            ;;
    esac
}

_image_filename() {
    local arch
    arch="$(_image_arch)" || return 1
    echo "limacode-base-${arch}.qcow2"
}

image_local_path() {
    local filename
    filename="$(_image_filename)" || return 1
    echo "${LIMACODE_CONFIG_DIR}/images/${filename}"
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

image_download() {
    local filename
    filename="$(_image_filename)" || return 1
    local url="${LIMACODE_RELEASE_URL}/${filename}"
    local dest
    dest="$(image_local_path)" || return 1

    local image_dir
    image_dir="$(dirname "$dest")"
    mkdir -p "$image_dir"

    log "Downloading pre-built image from ${url}..."
    if curl -fSL --progress-bar -o "${dest}.tmp" "$url" >&2 2>&1; then
        mv "${dest}.tmp" "$dest"
        log "Image downloaded: ${dest}"
        return 0
    else
        rm -f "${dest}.tmp"
        log "No pre-built image available for download."
        return 1
    fi
}

# Export a Lima instance's disk as a standalone qcow2 image
_image_export() {
    local instance="$1"
    local output="$2"
    local lima_dir="${HOME}/.lima/${instance}"

    local source=""
    if [[ -f "${lima_dir}/diffdisk" ]]; then
        source="${lima_dir}/diffdisk"
    elif [[ -f "${lima_dir}/disk" ]]; then
        source="${lima_dir}/disk"
    else
        error "No disk found for instance ${instance}"
        return 1
    fi

    if command -v qemu-img &>/dev/null; then
        qemu-img convert -O qcow2 -c "$source" "$output" >&2
    else
        cp "$source" "$output"
    fi
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

    if ! limactl create --name="$temp_instance" --tty=false "$build_yaml" >&2; then
        rm -f "$build_yaml"
        error "Failed to create build VM"
        return 1
    fi
    rm -f "$build_yaml"

    if ! limactl start --tty=false --timeout=15m "$temp_instance" >&2; then
        limactl delete -f "$temp_instance" >/dev/null 2>&1
        error "Failed to start build VM"
        return 1
    fi

    log "Running provision script..."
    if ! limactl shell "$temp_instance" -- bash < "$provision_script" >&2; then
        limactl stop "$temp_instance" >/dev/null 2>&1
        limactl delete -f "$temp_instance" >/dev/null 2>&1
        error "Provisioning failed"
        return 1
    fi

    limactl stop "$temp_instance" >&2

    local dest
    dest="$(image_local_path)" || return 1
    local image_dir
    image_dir="$(dirname "$dest")"
    mkdir -p "$image_dir"

    log "Exporting image..."
    if ! _image_export "$temp_instance" "$dest"; then
        limactl delete -f "$temp_instance" >/dev/null 2>&1
        error "Failed to export image"
        return 1
    fi

    limactl delete -f "$temp_instance" >/dev/null 2>&1

    log "Base image built: ${dest}"
}

image_update() {
    log "Updating limacode base image with latest agents..."
    image_build "$@"
    log "Update complete. New instances will use the updated image."
}

# Resolve the image to use: local > download > build
# Prints the local image path on success, returns 1 on failure
image_resolve() {
    if image_exists; then
        log "Using pre-built image: $(image_local_path)"
        image_local_path
        return 0
    fi

    if image_download; then
        image_local_path
        return 0
    fi

    log "Building image locally (this is a one-time setup)..."
    if image_build; then
        image_local_path
        return 0
    fi

    return 1
}
