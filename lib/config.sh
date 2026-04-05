#!/usr/bin/env bash
# Config module — read/write ~/.limacode/config
# Flat KEY=value format. CLI flags override config values override defaults.

LIMACODE_CONFIG_DIR="${LIMACODE_CONFIG_DIR:-${HOME}/.limacode}"
LIMACODE_CONFIG_FILE="${LIMACODE_CONFIG_DIR}/config"

# Valid config keys
_CONFIG_KEYS="agent adir restrict-dns env provision-script image"

_config_default() {
    local key="$1"
    case "$key" in
        agent) printf '%s' "claude-code" ;;
        *)     printf '%s' "" ;;
    esac
}

config_get() {
    local key="$1"
    local value=""

    # Read from file if it exists
    if [[ -f "${LIMACODE_CONFIG_FILE}" ]]; then
        value="$(grep "^${key}=" "${LIMACODE_CONFIG_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2-)"
    fi

    # Fall back to default
    if [[ -z "$value" ]]; then
        value="$(_config_default "$key")"
    fi

    printf '%s' "$value"
}

config_set() {
    local key="$1"
    local value="$2"

    mkdir -p "${LIMACODE_CONFIG_DIR}"

    # Rewrite the config file to avoid sed portability issues.
    local tmp_file="${LIMACODE_CONFIG_FILE}.tmp"
    local found=false

    if [[ -f "${LIMACODE_CONFIG_FILE}" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "${key}="* ]]; then
                echo "${key}=${value}"
                found=true
            else
                echo "$line"
            fi
        done < "${LIMACODE_CONFIG_FILE}" > "$tmp_file"
        mv "$tmp_file" "${LIMACODE_CONFIG_FILE}"
    fi

    if [[ "$found" == false ]]; then
        echo "${key}=${value}" >> "${LIMACODE_CONFIG_FILE}"
    fi
}

config_list() {
    for key in ${_CONFIG_KEYS}; do
        local value
        value="$(config_get "$key")"
        echo "${key}=${value}"
    done
}
