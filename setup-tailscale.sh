#!/usr/bin/env bash
# =============================================================
# Tailscale Auto-Setup Script
# Works on: macOS (Intel/ARM), Linux (Debian/Ubuntu/Fedora/Arch)
# Usage:    curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/setup-tailscale.sh | bash
# =============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# --- Detect OS ---
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
        # Add brew to PATH for Apple Silicon
        if [ "$ARCH" = "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        fi
    else
        log "Homebrew already installed"
    fi

    # Install Tailscale
    if ! brew list --cask tailscale &>/dev/null; then
        log "Installing Tailscale..."
        brew install --cask tailscale
    else
        log "Tailscale already installed"
    fi

    # Open Tailscale app (registers as login item automatically)
    log "Launching Tailscale..."
    open /Applications/Tailscale.app

    # Wait for Tailscale daemon to be ready
    log "Waiting for Tailscale to start..."
    for i in $(seq 1 30); do
        if command -v tailscale &>/dev/null && tailscale status &>/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    # Enable SSH
    log "Enabling Tailscale SSH..."
    tailscale up --ssh

    # Enable macOS Remote Login (sshd) if not already on
    if ! sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        warn "Enabling macOS Remote Login (SSH)..."
        sudo systemsetup -setremotelogin on
    fi

    log "macOS setup complete!"
    log "Tailscale runs on login automatically via the menu bar app."

# =============================================================
# Linux
# =============================================================
elif [ "$OS" = "Linux" ]; then

    # Install Tailscale using official script
    if ! command -v tailscale &>/dev/null; then
        log "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    else
        log "Tailscale already installed"
    fi

    # Enable and start the daemon
    log "Enabling tailscaled service..."
    sudo systemctl enable --now tailscaled

    # Bring up Tailscale with SSH
    log "Starting Tailscale with SSH..."
    sudo tailscale up --ssh

    # Ensure sshd is running
    if command -v systemctl &>/dev/null; then
        sudo systemctl enable --now sshd 2>/dev/null || sudo systemctl enable --now ssh 2>/dev/null || true
    fi

    log "Linux setup complete!"

# =============================================================
# Unsupported OS
# =============================================================
else
    err "Unsupported OS: $OS. For Windows, download Tailscale from https://tailscale.com/download/windows"
fi

# =============================================================
# Print status
# =============================================================
echo ""
log "========================================="
log "  Tailscale is installed and running!"
log "========================================="
echo ""
tailscale status 2>/dev/null || warn "Run 'tailscale status' after signing in"
echo ""
log "Your Tailscale IP:"
tailscale ip -4 2>/dev/null || warn "Sign in first, then run 'tailscale ip -4'"
echo ""
log "SSH from anywhere: ssh $(whoami)@$(tailscale ip -4 2>/dev/null || echo '<your-tailscale-ip>')"
echo ""
