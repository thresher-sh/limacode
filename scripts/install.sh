#!/bin/sh
# Limacode installer — POSIX sh for portability
# Usage: curl -fsSL https://code.thresher.sh/install | sh
# Non-interactive: curl ... | sh -s -- --yes --image=download-now
set -eu

LIMACODE_VERSION="${LIMACODE_VERSION:-0.1.0}"
LIMACODE_REPO="thresher-sh/limacode"
LIMACODE_INSTALL_DIR="${HOME}/.limacode/bin"
LIMACODE_CONFIG_DIR="${HOME}/.limacode"

AUTO_YES=false
IMAGE_CHOICE=""

log()   { printf '%s\n' "$*"; }
warn()  { printf 'WARNING: %s\n' "$*" >&2; }
die()   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

confirm() {
    if [ "$AUTO_YES" = true ]; then return 0; fi
    printf '%s [Y/n] ' "$1"
    read -r answer
    case "$answer" in
        [nN]*) return 1 ;;
        *) return 0 ;;
    esac
}

detect_platform() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    case "$OS" in
        Darwin) PLATFORM_OS="darwin" ;;
        Linux)  PLATFORM_OS="linux" ;;
        *)      die "Unsupported OS: $OS" ;;
    esac
    case "$ARCH" in
        x86_64|amd64)  PLATFORM_ARCH="amd64" ;;
        arm64|aarch64) PLATFORM_ARCH="arm64" ;;
        *)             die "Unsupported architecture: $ARCH" ;;
    esac
    PLATFORM="${PLATFORM_OS}-${PLATFORM_ARCH}"
}

checksum_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        die "No sha256sum or shasum found"
    fi
}

detect_shell_rc() {
    SHELL_NAME="$(basename "${SHELL:-/bin/sh}")"
    case "$SHELL_NAME" in
        zsh)  SHELL_RC="${HOME}/.zshrc" ;;
        bash) SHELL_RC="${HOME}/.bashrc" ;;
        fish) SHELL_RC="${HOME}/.config/fish/config.fish" ;;
        *)    SHELL_RC="${HOME}/.profile" ;;
    esac
}

detect_package_manager() {
    if [ "$PLATFORM_OS" = "darwin" ]; then
        PKG_MGR="brew"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
    else
        PKG_MGR="none"
    fi
}

pkg_install() {
    case "$PKG_MGR" in
        brew)   brew install "$@" ;;
        apt)    sudo apt-get install -y -qq "$@" ;;
        dnf)    sudo dnf install -y -q "$@" ;;
        pacman) sudo pacman -S --noconfirm "$@" ;;
        none)   die "No package manager found. Install manually: $*" ;;
    esac
}

check_prerequisites() {
    MISSING=""
    INSTALL_LIST=""

    log "Checking prerequisites..."

    if command -v curl >/dev/null 2>&1; then
        log "  ✓ curl found"
    else
        log "  ✗ curl not found"
        MISSING="$MISSING curl"
        INSTALL_LIST="$INSTALL_LIST curl"
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        log "  ✓ checksum tool found (sha256sum)"
    elif command -v shasum >/dev/null 2>&1; then
        log "  ✓ checksum tool found (shasum)"
    else
        log "  ✗ checksum tool not found"
        MISSING="$MISSING checksum"
    fi

    if command -v jq >/dev/null 2>&1; then
        log "  ✓ jq found"
    else
        log "  ✗ jq not found"
        MISSING="$MISSING jq"
        INSTALL_LIST="$INSTALL_LIST jq"
    fi

    if command -v limactl >/dev/null 2>&1; then
        LIMA_VERSION="$(limactl --version 2>/dev/null | head -1)"
        log "  ✓ Lima found (${LIMA_VERSION})"
    else
        log "  ✗ Lima not found"
        MISSING="$MISSING lima"
        INSTALL_LIST="$INSTALL_LIST lima"
    fi

    if [ "$PLATFORM_OS" = "linux" ]; then
        if command -v qemu-system-x86_64 >/dev/null 2>&1 || command -v qemu-system-aarch64 >/dev/null 2>&1; then
            log "  ✓ QEMU found"
        else
            log "  ✗ QEMU not found"
            MISSING="$MISSING qemu"
            INSTALL_LIST="$INSTALL_LIST qemu-system"
        fi
    fi

    if [ "$PLATFORM_OS" = "darwin" ] && [ -n "$MISSING" ]; then
        if ! command -v brew >/dev/null 2>&1; then
            log ""
            log "Homebrew is required to install prerequisites on macOS."
            if confirm "Install Homebrew?"; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            else
                die "Homebrew required. Install from https://brew.sh"
            fi
        fi
    fi

    if [ -n "$MISSING" ]; then
        log ""
        log "The following will be installed:"
        for pkg in $INSTALL_LIST; do
            log "  - ${pkg} (via ${PKG_MGR})"
        done
        log ""
        if confirm "Install missing prerequisites?"; then
            for pkg in $INSTALL_LIST; do
                pkg_install "$pkg"
                log "  ✓ ${pkg} installed"
            done
        else
            log ""
            log "Manual install instructions:"
            for pkg in $MISSING; do
                case "$pkg" in
                    lima)     log "  Lima: https://lima-vm.io/docs/installation/" ;;
                    jq)       log "  jq: https://jqlang.github.io/jq/download/" ;;
                    curl)     log "  curl: https://curl.se/download.html" ;;
                    qemu)     log "  QEMU: https://www.qemu.org/download/" ;;
                    checksum) log "  sha256sum: install coreutils" ;;
                esac
            done
            die "Prerequisites missing. Install them and re-run."
        fi
    fi

    log ""
    log "All prerequisites met."
}

install_cli() {
    TARBALL="limacode-v${LIMACODE_VERSION}-${PLATFORM}.tar.gz"
    TARBALL_URL="https://github.com/${LIMACODE_REPO}/releases/download/v${LIMACODE_VERSION}/${TARBALL}"
    CHECKSUM_URL="${TARBALL_URL}.sha256"

    log ""
    log "Will download:"
    log "  ${TARBALL}"

    EXPECTED_CHECKSUM="$(curl -fsSL "$CHECKSUM_URL" 2>/dev/null | cut -d' ' -f1 || echo "unavailable")"
    log "  SHA-256: ${EXPECTED_CHECKSUM}"

    log ""
    if ! confirm "Proceed with install?"; then
        die "Installation cancelled."
    fi

    log ""
    log "=== Installing CLI... ==="

    TEMP_DIR="$(mktemp -d)"
    TEMP_FILE="${TEMP_DIR}/${TARBALL}"
    curl --proto '=https' --tlsv1.2 -fsSL -o "$TEMP_FILE" "$TARBALL_URL" || die "Download failed"

    if [ "$EXPECTED_CHECKSUM" != "unavailable" ]; then
        ACTUAL_CHECKSUM="$(checksum_cmd "$TEMP_FILE")"
        if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
            rm -rf "$TEMP_DIR"
            die "Checksum mismatch! Expected: ${EXPECTED_CHECKSUM}, Got: ${ACTUAL_CHECKSUM}"
        fi
        log "  ✓ Downloaded and verified checksum"
    else
        warn "Could not fetch checksum. Proceeding without verification."
        log "  ✓ Downloaded (checksum not verified)"
    fi

    mkdir -p "$LIMACODE_INSTALL_DIR"
    tar -xzf "$TEMP_FILE" -C "$LIMACODE_INSTALL_DIR" --strip-components=1
    chmod +x "${LIMACODE_INSTALL_DIR}/limacode.sh"
    rm -rf "$TEMP_DIR"
    log "  ✓ Extracted to ${LIMACODE_INSTALL_DIR}/"

    ln -sf "${LIMACODE_INSTALL_DIR}/limacode.sh" "${LIMACODE_INSTALL_DIR}/limacode"

    if ! echo "$PATH" | grep -q "${LIMACODE_INSTALL_DIR}"; then
        case "$SHELL_NAME" in
            fish) EXPORT_LINE="fish_add_path ${LIMACODE_INSTALL_DIR}" ;;
            *)    EXPORT_LINE="export PATH=\"${LIMACODE_INSTALL_DIR}:\$PATH\"" ;;
        esac
        if ! grep -q "limacode" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# limacode" >> "$SHELL_RC"
            echo "$EXPORT_LINE" >> "$SHELL_RC"
            log "  ✓ Added to PATH in ${SHELL_RC}"
        else
            log "  ✓ PATH already configured in ${SHELL_RC}"
        fi
    else
        log "  ✓ Already in PATH"
    fi
}

choose_image() {
    log ""
    log "=== Base VM Image ==="
    log "The base image has all agents pre-installed for instant startup."
    log ""
    log "  A) Download image now (~2 GB)"
    log "  B) Download image on first run"
    log "  C) Build image locally during install (~5-10 min)"
    log ""

    if [ -n "$IMAGE_CHOICE" ]; then
        case "$IMAGE_CHOICE" in
            download-now)   IMAGE_CHOICE="A" ;;
            download-later) IMAGE_CHOICE="B" ;;
            build-local)    IMAGE_CHOICE="C" ;;
        esac
        choice="$IMAGE_CHOICE"
    elif [ "$AUTO_YES" = true ]; then
        choice="B"
    else
        printf "Choice [A/B/C]: "
        read -r choice
    fi

    case "$choice" in
        [aA])
            log "Downloading base image..."
            log "  (Image download not yet implemented — will be available in first release)"
            ;;
        [bB])
            log "Image will be downloaded on first run."
            ;;
        [cC])
            log "Building base image locally..."
            "${LIMACODE_INSTALL_DIR}/limacode.sh" build
            log "  ✓ Base image built"
            ;;
        *)
            warn "Invalid choice. Defaulting to download on first run."
            ;;
    esac
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes) AUTO_YES=true; shift ;;
            --image=*) IMAGE_CHOICE="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done

    log "=== limacode v${LIMACODE_VERSION} installer ==="
    log ""

    detect_platform
    detect_shell_rc
    detect_package_manager

    log "Platform:   ${PLATFORM}"
    log "Install to: ${LIMACODE_INSTALL_DIR}/"
    log "Shell:      ${SHELL_NAME} (${SHELL_RC})"
    log ""

    check_prerequisites
    install_cli
    choose_image

    log ""
    log "=== Done! ==="
    log "Run 'limacode' in any project directory to get started."
    log ""
    log "You may need to restart your shell or run:"
    log "  source ${SHELL_RC}"
}

main "$@" || exit 1
