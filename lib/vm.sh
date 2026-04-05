#!/usr/bin/env bash
# VM lifecycle module — Lima VM create, start, stop, shell, delete, list

vm_cwd_hash() {
    local path="$1"
    if command -v sha256sum &>/dev/null; then
        printf '%s' "$path" | sha256sum | cut -c1-6
    elif command -v shasum &>/dev/null; then
        printf '%s' "$path" | shasum -a 256 | cut -c1-6
    else
        echo "ERROR: No sha256sum or shasum found" >&2
        return 1
    fi
}

vm_next_unique_int() {
    local agent="$1"
    local hash="$2"
    local prefix="limacode-${agent}-${hash}-"
    local max=0
    local instances
    instances="$(limactl list --format json 2>/dev/null || echo "[]")"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if [[ "$name" == ${prefix}* ]]; then
            local num="${name##"${prefix}"}"
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num > max )); then
                max=$num
            fi
        fi
    done < <(echo "$instances" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

    echo $(( max + 1 ))
}

vm_instance_name() {
    local agent="$1"
    local project_dir="$2"
    local hash
    hash="$(vm_cwd_hash "$project_dir")"
    local unique_int
    unique_int="$(vm_next_unique_int "$agent" "$hash")"
    echo "limacode-${agent}-${hash}-${unique_int}"
}

vm_create() {
    local instance_name="$1"
    local yaml_file="$2"
    log "Creating VM: ${instance_name}"
    if ! limactl create --name="$instance_name" --tty=false "$yaml_file" 2>&1; then
        error "Failed to create VM. Check Lima logs at ~/.lima/${instance_name}/ha.stderr.log"
        return 1
    fi
}

vm_start() {
    local instance_name="$1"
    log "Starting VM: ${instance_name}"
    if ! limactl start --tty=false --timeout=10m "$instance_name" 2>&1; then
        error "Failed to start VM (timeout or error). Check ~/.lima/${instance_name}/ha.stderr.log"
        limactl delete -f "$instance_name" 2>/dev/null
        return 1
    fi
}

vm_shell() {
    local instance_name="$1"
    shift
    limactl shell "$instance_name" -- "$@"
}

vm_shell_with_env() {
    local instance_name="$1"
    local env_spec="$2"
    shift 2
    (
        if [[ -n "$env_spec" ]]; then
            local IFS=','
            for entry in $env_spec; do
                export "${entry?}"
            done
        fi
        limactl shell --preserve-env "$instance_name" -- "$@"
    )
}

vm_stop() {
    local instance_name="$1"
    log "Stopping VM: ${instance_name}"
    limactl stop "$instance_name" 2>/dev/null || true
}

vm_delete() {
    local instance_name="$1"
    limactl delete -f "$instance_name" 2>/dev/null || true
}

vm_cleanup() {
    local instance_name="$1"
    vm_stop "$instance_name"
    vm_delete "$instance_name"
}

vm_list() {
    local instances
    instances="$(limactl list --format json 2>/dev/null || echo "[]")"
    echo "$instances" | grep -o '"name":"limacode-[^"]*"' | cut -d'"' -f4
}

vm_list_detail() {
    limactl list 2>/dev/null | grep "^limacode-" || true
}

vm_pick_instance() {
    local instances=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && instances+=("$name")
    done < <(vm_list)

    local count=${#instances[@]}

    if [[ $count -eq 0 ]]; then
        echo "ERROR: No running limacode instances found" >&2
        return 1
    fi

    if [[ $count -eq 1 ]]; then
        echo "${instances[0]}"
        return 0
    fi

    echo "Multiple limacode instances running:" >&2
    local i=1
    for inst in "${instances[@]}"; do
        echo "  ${i}) ${inst}" >&2
        (( i++ ))
    done
    printf "Choose [1-%d]: " "$count" >&2
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
        echo "${instances[$((choice - 1))]}"
        return 0
    fi

    echo "ERROR: Invalid choice" >&2
    return 1
}
