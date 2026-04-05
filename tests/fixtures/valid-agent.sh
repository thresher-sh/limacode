AGENT_NAME="valid-agent"
AGENT_DESCRIPTION="A valid test agent"
AGENT_DEPS=""

agent_install() {
    echo "installing valid-agent"
}

agent_cmd() {
    echo "valid-agent" "--headless" "$@"
}

agent_cmd_interactive() {
    echo "valid-agent"
}

agent_env_hint() {
    echo "Hint: set VALID_AGENT_KEY"
}
