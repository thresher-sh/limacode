AGENT_NAME="claude-code"
AGENT_DESCRIPTION="Anthropic's Claude Code terminal agent"
AGENT_DEPS=""

agent_install() {
    curl -fsSL https://claude.ai/install.sh | bash
}

agent_cmd() {
    echo "claude" "-p" "--dangerously-skip-permissions" "$@"
}

agent_cmd_interactive() {
    echo "claude"
}

agent_env_hint() {
    echo "Hint: forward your API key with --env ANTHROPIC_API_KEY=<your-key>"
}
