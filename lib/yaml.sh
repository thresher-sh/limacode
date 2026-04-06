#!/usr/bin/env bash
# YAML generation module — produces Lima YAML for VM creation

_yaml_detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "vz" ;;
        Linux)  echo "qemu" ;;
        *)      echo "qemu" ;;
    esac
}

_yaml_detect_mount_type() {
    case "$(uname -s)" in
        Darwin) echo "virtiofs" ;;
        *)      echo "9p" ;;
    esac
}

_yaml_adir_mounts() {
    local adir_spec="$1"
    [[ -z "$adir_spec" ]] && return 0

    local IFS=','
    for entry in $adir_spec; do
        local name="${entry%%:*}"
        local path="${entry#*:}"

        if [[ "$name" == "current" ]]; then
            echo "ERROR: 'current' is a reserved mount name" >&2
            return 1
        fi

        path="${path/#\~/$HOME}"

        cat <<MOUNT
- location: "${path}"
  mountPoint: "/home/{{.User}}/workspace/${name}"
  writable: true
MOUNT
    done
}

# Generate restrict-dns provisioning block for Lima YAML
# Delegates to network.sh for the actual iptables script content
_yaml_restrict_dns_provision() {
    local dns_list="$1"
    [[ -z "$dns_list" ]] && return 0

    local script_content
    script_content="$(network_generate_iptables_script "$dns_list")"

    echo "- mode: system"
    echo "  script: |"
    echo "$script_content" | while IFS= read -r line; do
        echo "    ${line}"
    done
}

# Main YAML generation function
# Args: project_dir [image_location] [adir_spec] [restrict_dns]
yaml_generate() {
    local project_dir="$1"
    local image_location="${2:-}"
    local adir_spec="${3:-}"
    local restrict_dns="${4:-}"

    local vm_type mount_type
    vm_type="$(_yaml_detect_platform)"
    mount_type="$(_yaml_detect_mount_type)"

    # Validate adir
    if [[ -n "$adir_spec" ]]; then
        local IFS=','
        for entry in $adir_spec; do
            local name="${entry%%:*}"
            if [[ "$name" == "current" ]]; then
                echo "ERROR: 'current' is a reserved mount name" >&2
                return 1
            fi
        done
    fi

    local host_arch
    host_arch="$(uname -m)"

    local lima_arch img_arch
    case "$host_arch" in
        aarch64|arm64)
            lima_arch="aarch64"
            img_arch="arm64"
            ;;
        x86_64|amd64)
            lima_arch="x86_64"
            img_arch="amd64"
            ;;
        *)
            echo "ERROR: Unsupported architecture: ${host_arch}" >&2
            return 1
            ;;
    esac

    if [[ -z "$image_location" ]]; then
        image_location="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-${img_arch}.img"
    fi

    cat <<YAML
vmType: ${vm_type}
arch: default
cpus: 4
memory: "4GiB"
disk: "50GiB"

images:
- location: "${image_location}"
  arch: "${lima_arch}"

mountType: "${mount_type}"

mounts:
- location: "${project_dir}"
  mountPoint: "/home/{{.User}}/workspace/current"
  writable: true
YAML

    if [[ -n "$adir_spec" ]]; then
        _yaml_adir_mounts "$adir_spec" || return 1
    fi

    cat <<'YAML'

ssh:
  localPort: 0
  forwardAgent: true
  loadDotSSHPubKeys: false

propagateProxyEnv: true

portForwards:
- guestPortRange: [3000, 9999]
  hostIP: "127.0.0.1"

containerd:
  system: false
  user: false

video:
  display: "none"
YAML

    if [[ -n "$restrict_dns" ]]; then
        echo ""
        echo "provision:"
        _yaml_restrict_dns_provision "$restrict_dns"
    fi
}
