AGENT_NAME="wrong-name"
AGENT_DESCRIPTION="Name does not match filename"

agent_install() {
    echo "installing"
}

agent_cmd() {
    echo "wrong-name" "$@"
}

agent_cmd_interactive() {
    echo "wrong-name"
}
