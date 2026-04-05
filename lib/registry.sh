#!/usr/bin/env bash
# Registry module — load and validate agent definitions from registry/

# Disallowed patterns in agent files (checked before sourcing)
# These are checked against non-comment lines only
_REGISTRY_DISALLOWED_PATTERNS=(
    '\beval\b'
    'rm -rf /'
    '^\s*source\b'
    '^\s*\. /'
)

# Required function names
_REGISTRY_REQUIRED_FUNCS=(
    "agent_install"
    "agent_cmd"
    "agent_cmd_interactive"
)

# Required variable names
_REGISTRY_REQUIRED_VARS=(
    "AGENT_NAME"
    "AGENT_DESCRIPTION"
)

registry_validate() {
    local agent_file="$1"

    # Check file exists
    if [[ ! -f "$agent_file" ]]; then
        echo "ERROR: Agent file not found: ${agent_file}" >&2
        return 1
    fi

    if [[ ! -r "$agent_file" ]]; then
        echo "ERROR: Agent file not readable: ${agent_file}" >&2
        return 1
    fi

    local content
    content="$(cat "$agent_file")"

    # Check disallowed patterns (strip comments first)
    local code_lines
    code_lines="$(echo "$content" | grep -v '^\s*#')"
    for pattern in "${_REGISTRY_DISALLOWED_PATTERNS[@]}"; do
        if echo "$code_lines" | grep -qE "$pattern"; then
            echo "ERROR: Agent file contains disallowed pattern: ${pattern}" >&2
            return 1
        fi
    done

    # Check required variables declared
    for var in "${_REGISTRY_REQUIRED_VARS[@]}"; do
        if ! echo "$content" | grep -q "^${var}="; then
            echo "ERROR: Agent file missing required variable: ${var}" >&2
            return 1
        fi
    done

    # Check required functions declared
    for func in "${_REGISTRY_REQUIRED_FUNCS[@]}"; do
        if ! echo "$content" | grep -q "${func}()"; then
            echo "ERROR: Agent file missing required function: ${func}" >&2
            return 1
        fi
    done

    # Source in subshell for post-source checks
    local agent_name
    agent_name="$(bash -c 'source "$1" && echo "$AGENT_NAME"' _ "$agent_file")"

    # Check name contains only [a-z0-9-]
    if [[ ! "$agent_name" =~ ^[a-z0-9-]+$ ]]; then
        echo "ERROR: AGENT_NAME must contain only lowercase letters, numbers, and hyphens" >&2
        return 1
    fi

    # Check name matches filename
    local expected_name
    expected_name="$(basename "$agent_file" .sh)"
    if [[ "$agent_name" != "$expected_name" ]]; then
        echo "ERROR: AGENT_NAME '${agent_name}' does not match filename '${expected_name}'" >&2
        return 1
    fi

    # Verify functions are callable
    for func in "${_REGISTRY_REQUIRED_FUNCS[@]}"; do
        if ! bash -c 'source "$1" && type -t "$2"' _ "$agent_file" "$func" &>/dev/null; then
            echo "ERROR: Function ${func} not callable after sourcing" >&2
            return 1
        fi
    done

    return 0
}

registry_load() {
    local agent_file="$1"

    registry_validate "$agent_file" || return 1

    # Source into current shell
    source "$agent_file"
}

registry_find() {
    local agent_name="$1"
    local registry_dir="$2"

    local agent_file="${registry_dir}/${agent_name}.sh"
    if [[ -f "$agent_file" ]]; then
        echo "$agent_file"
        return 0
    fi

    echo "ERROR: Agent '${agent_name}' not found in registry at ${registry_dir}" >&2
    return 1
}

registry_list_agents() {
    local registry_dir="$1"

    if [[ ! -d "$registry_dir" ]]; then
        echo "ERROR: Registry directory not found: ${registry_dir}" >&2
        return 1
    fi

    for agent_file in "${registry_dir}"/*.sh; do
        [[ -f "$agent_file" ]] || continue
        local name desc
        name="$(grep '^AGENT_NAME=' "$agent_file" | head -1 | cut -d'"' -f2)"
        desc="$(grep '^AGENT_DESCRIPTION=' "$agent_file" | head -1 | cut -d'"' -f2)"
        printf '  %-20s %s\n' "$name" "$desc"
    done
}
