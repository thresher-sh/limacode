#!/usr/bin/env bash
AGENT_NAME="opencode"
AGENT_DESCRIPTION="Go-based terminal AI coding agent by terminal.shop"
AGENT_DEPS=""

agent_install() {
    curl -fsSL https://opencode.ai/install | bash
}

agent_cmd() {
    echo "opencode" "-p" "$@"
}

agent_cmd_interactive() {
    echo "opencode"
}

agent_env_hint() {
    echo "Hint: forward your API key with --env ANTHROPIC_API_KEY=<your-key> (or OPENAI_API_KEY, GOOGLE_API_KEY)"
}
