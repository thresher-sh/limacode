#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
PROG="limacode"

# Resolve script directory (works on macOS bash 3.2 which lacks readlink -f)
LIMACODE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library modules
source "${LIMACODE_ROOT}/lib/config.sh"
source "${LIMACODE_ROOT}/lib/registry.sh"
source "${LIMACODE_ROOT}/lib/yaml.sh"
source "${LIMACODE_ROOT}/lib/vm.sh"
source "${LIMACODE_ROOT}/lib/network.sh"
source "${LIMACODE_ROOT}/lib/image.sh"

# --- Logging ---
log()   { printf '%s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

# --- Cleanup ---
_cleanup_instance=""
_cleanup_yaml=""
_run_cleanup() {
    [[ -n "$_cleanup_instance" ]] && vm_cleanup "$_cleanup_instance"
    [[ -n "$_cleanup_yaml" ]] && rm -f "$_cleanup_yaml"
}

# --- Argument parsing ---
_parse_global_opts() {
    LIMACODE_AGENT=""
    LIMACODE_ADIR=""
    LIMACODE_RESTRICT_DNS=""
    LIMACODE_ENV=""
    LIMACODE_PROVISION_SCRIPT=""
    LIMACODE_IMAGE=""
    LIMACODE_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)           LIMACODE_AGENT="$2"; shift 2 ;;
            --adir)            LIMACODE_ADIR="$2"; shift 2 ;;
            --restrict-dns)    LIMACODE_RESTRICT_DNS="$2"; shift 2 ;;
            --env)             LIMACODE_ENV="$2"; shift 2 ;;
            --provision-script) LIMACODE_PROVISION_SCRIPT="$2"; shift 2 ;;
            --image)           LIMACODE_IMAGE="$2"; shift 2 ;;
            --)                shift; LIMACODE_ARGS+=("$@"); break ;;
            -*)                error "Unknown option: $1"; cmd_help; exit 1 ;;
            *)                 LIMACODE_ARGS+=("$1"); shift ;;
        esac
    done

    # Apply config defaults where flags not set
    [[ -z "$LIMACODE_AGENT" ]] && LIMACODE_AGENT="$(config_get agent)"
    [[ -z "$LIMACODE_ADIR" ]] && LIMACODE_ADIR="$(config_get adir)"
    [[ -z "$LIMACODE_RESTRICT_DNS" ]] && LIMACODE_RESTRICT_DNS="$(config_get restrict-dns)"
    [[ -z "$LIMACODE_ENV" ]] && LIMACODE_ENV="$(config_get env)"
    [[ -z "$LIMACODE_PROVISION_SCRIPT" ]] && LIMACODE_PROVISION_SCRIPT="$(config_get provision-script)"
    [[ -z "$LIMACODE_IMAGE" ]] && LIMACODE_IMAGE="$(config_get image)"
}

# --- Commands ---
cmd_run() {
    local project_dir
    project_dir="$(pwd)"

    if ! command -v limactl &>/dev/null; then
        error "Lima is not installed. Install with: brew install lima"
        exit 1
    fi

    local agent_file
    agent_file="$(registry_find "$LIMACODE_AGENT" "${LIMACODE_ROOT}/registry")" || exit 1
    registry_load "$agent_file" || exit 1

    local yaml_file
    yaml_file="$(mktemp /tmp/limacode-XXXXXX.yaml)"
    yaml_generate "$project_dir" "$LIMACODE_IMAGE" "$LIMACODE_ADIR" "$LIMACODE_RESTRICT_DNS" > "$yaml_file"

    local instance_name
    instance_name="$(vm_instance_name "$LIMACODE_AGENT" "$project_dir")"

    _cleanup_instance="$instance_name"
    _cleanup_yaml="$yaml_file"
    trap '_run_cleanup' EXIT INT TERM

    vm_create "$instance_name" "$yaml_file" || exit 1
    rm -f "$yaml_file"

    vm_start "$instance_name" || exit 1

    log "Starting ${AGENT_DESCRIPTION} in sandbox..."
    local -a cmd_parts
    if [[ ${#LIMACODE_ARGS[@]} -gt 0 ]]; then
        read -ra cmd_parts <<< "$(agent_cmd "${LIMACODE_ARGS[@]}")"
        vm_shell_with_env "$instance_name" "$LIMACODE_ENV" "${cmd_parts[@]}"
    else
        read -ra cmd_parts <<< "$(agent_cmd_interactive)"
        vm_shell_with_env "$instance_name" "$LIMACODE_ENV" "${cmd_parts[@]}"
    fi
}

cmd_shell() {
    local instance
    instance="$(vm_pick_instance)" || exit 1
    limactl shell "$instance"
}

cmd_list() {
    local instances
    instances="$(vm_list_detail)"
    if [[ -z "$instances" ]]; then
        echo "No running limacode instances."
    else
        echo "Running limacode instances:"
        echo "$instances"
    fi
}

cmd_stop() {
    local instance="${1:-}"
    if [[ -z "$instance" ]]; then
        instance="$(vm_pick_instance)" || exit 1
    fi
    vm_cleanup "$instance"
    log "Instance ${instance} stopped and removed."
}

cmd_build() {
    image_build "${LIMACODE_PROVISION_SCRIPT}" "${LIMACODE_IMAGE}"
}

cmd_update() {
    image_update "${LIMACODE_PROVISION_SCRIPT}" "${LIMACODE_IMAGE}"
}

cmd_config() {
    local key="${1:-}"
    local value="${2:-}"

    if [[ -z "$key" ]]; then
        config_list
        return 0
    fi

    if [[ -z "$value" ]]; then
        config_get "$key"
        echo ""
        return 0
    fi

    config_set "$key" "$value"
    log "Set ${key}=${value}"
}

cmd_version() {
    echo "${PROG} v${VERSION}"
}

cmd_help() {
    cat <<HELP
Usage: ${PROG} [options] [-- agent-args...]
       ${PROG} <command> [args]

Run AI coding agents in sandboxed Lima VMs.

Commands:
  (default)     Create VM and run agent against current directory
  shell         Attach to a running instance
  list          Show running instances
  stop [id]     Stop and remove an instance
  build         Build the base VM image locally
  update        Rebuild base image with latest agent versions
  config        Get/set configuration
  version       Print version
  help          Show this help

Options:
  --agent <name>              Agent to run (default: claude-code)
  --adir <name>:<path>[,...]  Additional directory mounts
  --restrict-dns <list>       Comma-separated domain allowlist
  --env <KEY>=<VALUE>[,...]   Environment variables to forward
  --provision-script <path>   Custom provision script (build only)
  --image <name>              Custom base image (build only)

Available agents:
HELP
    registry_list_agents "${LIMACODE_ROOT}/registry"

    cat <<HELP

Config: ~/.limacode/config
Examples:
  ${PROG}                                    # Run default agent
  ${PROG} --agent opencode                   # Run OpenCode
  ${PROG} --env ANTHROPIC_API_KEY=sk-123     # Forward API key
  ${PROG} --adir libs:~/my-libs              # Mount extra directory
  ${PROG} config agent opencode              # Set default agent
HELP
}

# --- Main ---
main() {
    local cmd="${1:-}"

    case "$cmd" in
        shell|list|stop|build|update|config|version|help|--help|-h)
            shift || true
            _parse_global_opts "$@"
            ;;
        "")
            _parse_global_opts "$@"
            cmd="run"
            ;;
        -*)
            _parse_global_opts "$@"
            cmd="run"
            ;;
        *)
            if type "cmd_${cmd}" &>/dev/null 2>&1; then
                shift || true
                _parse_global_opts "$@"
            else
                error "Unknown command: ${cmd}"
                cmd_help
                exit 1
            fi
            ;;
    esac

    case "$cmd" in
        run)     cmd_run ;;
        shell)   cmd_shell ;;
        list)    cmd_list ;;
        stop)    cmd_stop "${LIMACODE_ARGS[0]:-}" ;;
        build)   cmd_build ;;
        update)  cmd_update ;;
        config)  cmd_config "${LIMACODE_ARGS[@]:+${LIMACODE_ARGS[@]}}" ;;
        version) cmd_version ;;
        help|--help|-h) cmd_help ;;
        *)       error "Unknown command: ${cmd}"; cmd_help; exit 1 ;;
    esac
}

main "$@"
