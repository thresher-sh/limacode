#!/usr/bin/env bash
AGENT_NAME="pi"
AGENT_DESCRIPTION="Minimal, extensible terminal coding agent by Mario Zechner"
AGENT_DEPS=""

agent_install() {
    npm install -g @mariozechner/pi-coding-agent
}

agent_cmd() {
    echo "pi" "-p" "$@"
}

agent_cmd_interactive() {
    echo "pi"
}

agent_env_hint() {
    echo "Hint: forward your provider API key with --env (provider-specific)"
}
