#!/usr/bin/env bash
# =============================================================
# Tailscale Auto-Setup Script (Fully Headless, No GUI)
# Works on: macOS (Intel/ARM), Linux (Debian/Ubuntu/Fedora/Arch)
#
# Usage:
#   bash setup-tailscale.sh YOUR_AUTH_KEY
#   curl -fsSL https://raw.githubusercontent.com/seemandhar/Tailscale-setup/main/setup-tailscale.sh | bash -s -- YOUR_AUTH_KEY
#
# Get your auth key: login.tailscale.com → Settings → Keys → Generate auth key (check "Reusable")
# =============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

AUTH_KEY="${1:-}"
if [ -z "$AUTH_KEY" ]; then
    err "Auth key required. Usage: bash setup-tailscale.sh YOUR_AUTH_KEY\n    Get one at: https://login.tailscale.com/admin/settings/keys"
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
log "Detected: $OS ($ARCH)"

# =============================================================
# macOS
# =============================================================
if [ "$OS" = "Darwin" ]; then

    # Install Homebrew if missing
    if ! command -v brew &>/dev/null; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ "$ARCH" = "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        fi
    else
        log "Homebrew already installed"
    fi

    # Install Tailscale CLI (not the GUI app)
    if ! command -v tailscale &>/dev/null; then
        log "Installing Tailscale CLI..."
        brew install tailscale
    else
        log "Tailscale already installed"
    fi

    # Install and start system daemon (survives reboots)
    log "Installing system daemon..."
    sudo tailscaled install-system-daemon 2>/dev/null || true

    # Wait for daemon to be ready
    log "Starting tailscaled..."
    sleep 3

    # Authenticate headless with auth key + enable SSH
    log "Authenticating with auth key..."
    sudo tailscale up --ssh --authkey="$AUTH_KEY"

    # Enable macOS Remote Login (sshd)
    if ! sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        warn "Enabling macOS Remote Login (SSH)..."
        sudo systemsetup -setremotelogin on
    fi

    log "macOS setup complete!"

# =============================================================
# Linux
# =============================================================
elif [ "$OS" = "Linux" ]; then

    # Install Tailscale
    if ! command -v tailscale &>/dev/null; then
        log "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    else
        log "Tailscale already installed"
    fi

    # Enable and start daemon
    log "Enabling tailscaled service..."
    sudo systemctl enable --now tailscaled

    # Authenticate headless with auth key + enable SSH
    log "Authenticating with auth key..."
    sudo tailscale up --ssh --authkey="$AUTH_KEY"

    # Ensure sshd is running
    sudo systemctl enable --now sshd 2>/dev/null || sudo systemctl enable --now ssh 2>/dev/null || true

    log "Linux setup complete!"

# =============================================================
# Unsupported OS
# =============================================================
else
    err "Unsupported OS: $OS. For Windows, download from https://tailscale.com/download/windows"
fi

# =============================================================
# Status
# =============================================================
echo ""
log "========================================="
log "  Tailscale is installed and running!"
log "========================================="
echo ""
TSIP=$(sudo tailscale ip -4 2>/dev/null || echo "unknown")
log "Tailscale IP: $TSIP"
log "SSH command:  ssh $(whoami)@$TSIP"
log "MagicDNS:     ssh $(whoami)@$(hostname)"
echo ""
log "Manage devices: https://login.tailscale.com/admin/machines"
echo ""
