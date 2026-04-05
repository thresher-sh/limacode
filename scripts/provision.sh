#!/bin/bash
# Limacode base image provisioning script
# Installs all system dependencies, runtimes, and agents.
# Must be idempotent — safe to run multiple times.
set -euo pipefail

echo "=== Limacode: provisioning base image ==="

# --- System packages ---
echo "Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq \
    build-essential \
    curl \
    git \
    jq \
    unzip \
    wget \
    iptables \
    nftables \
    ca-certificates \
    dnsutils \
    cron

# --- Node.js 22+ via nvm ---
echo "Installing Node.js..."
export NVM_DIR="${HOME}/.nvm"
if [[ ! -d "${NVM_DIR}" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
fi
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh"
nvm install 22
nvm alias default 22

# --- Go (latest stable) ---
echo "Installing Go..."
if ! command -v go &>/dev/null; then
    GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        *)       GO_ARCH="$ARCH" ;;
    esac
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | sudo tar -C /usr/local -xzf -
    # shellcheck disable=SC2016
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "${HOME}/.bashrc"
    export PATH=$PATH:/usr/local/go/bin
fi

# --- Python 3 + pip ---
echo "Installing Python 3..."
sudo apt-get install -y -qq python3 python3-pip python3-venv

# --- Claude Code ---
echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash || true

# --- OpenCode ---
echo "Installing OpenCode..."
curl -fsSL https://opencode.ai/install | bash || true

# --- Pi.dev ---
echo "Installing Pi.dev..."
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh"
npm install -g @mariozechner/pi-coding-agent || true

echo "=== Limacode: provisioning complete ==="
