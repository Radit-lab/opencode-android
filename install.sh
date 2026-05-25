#!/data/data/com.termux/files/usr/bin/bash
#
# OpenCode Native Android Installer
# Installs OpenCode CLI natively on Termux (no emulators!)
#
# Repo: https://github.com/Radit-lab/opencode-android
# Author: Radit-lab
#

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Logging ──────────────────────────────────────────────────────────
log_info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

# ── Trap cleanup ─────────────────────────────────────────────────────
cleanup() {
  if [ $? -ne 0 ]; then
    echo -e "\n${RED} Installation failed at step: ${current_step:-unknown}${NC}"
    echo -e "${YELLOW} See the troubleshooting section in the README for help.${NC}"
  fi
}
trap cleanup EXIT

# ── Header ───────────────────────────────────────────────────────────
clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     OpenCode Native Android Installer    ║"
echo "  ║       No emulators. Pure native.         ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Check if already installed ───────────────────────────────────────
if command -v opencode &>/dev/null; then
  log_info "OpenCode is already installed at $(command -v opencode)"
  log_info "Version: $(opencode --version 2>/dev/null || echo 'unknown')"
  echo ""
  read -rp "Reinstall? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Exiting."
    exit 0
  fi
fi

# ── Phase 1: System Preparation ──────────────────────────────────────
current_step="System Preparation"
log_step "Phase 1: System Preparation"

log_info "Updating Termux packages..."
pkg update -y && pkg upgrade -y
log_ok "Packages updated"

log_info "Installing base dependencies (git, dpkg, nodejs)..."
pkg install git dpkg nodejs -y
log_ok "Dependencies installed"

# ── Phase 2: glibc & Certificates ────────────────────────────────────
current_step="glibc Installation"
log_step "Phase 2: Installing glibc Compatibility Layer"

log_info "Adding glibc repository..."
pkg install glibc-repo -y
log_ok "glibc repo added"

log_info "Installing glibc and CA certificates..."
pkg install glibc ca-certificates -y
log_ok "glibc and certificates installed"

# ── Phase 3: Build OpenCode ──────────────────────────────────────────
current_step="Building OpenCode"
log_step "Phase 3: Compiling OpenCode for Termux"

BUILD_DIR="$HOME/opencode-termux"

if [ -d "$BUILD_DIR" ]; then
  log_warn "Build directory exists. Removing..."
  rm -rf "$BUILD_DIR"
fi

log_info "Cloning opencode-termux build system..."
git clone https://github.com/Hope2333/opencode-termux.git "$BUILD_DIR"
cd "$BUILD_DIR"
log_ok "Cloned"

log_info "Producing local build (latest release)..."
./tools/produce-local.sh latest
log_ok "Local build produced"

log_info "Running build script..."
./scripts/build.sh
log_ok "Build complete"

log_info "Packaging .deb..."
./scripts/package/package_deb.sh
log_ok "Package created"

log_info "Installing package globally..."
dpkg -i packaging/dpkg/opencode_0.0.0_aarch64.deb
log_ok "OpenCode installed globally"

# ── Phase 4: SSL Configuration ───────────────────────────────────────
current_step="SSL Configuration"
log_step "Phase 4: Configuring SSL Certificates"

SSL_PATH="/data/data/com.termux/files/usr/etc/tls/cert.pem"

if [ ! -f "$SSL_PATH" ]; then
  log_warn "SSL certificate file not found at $SSL_PATH"
  log_warn "Will still add the environment variable — you may need to fix this manually."
fi

# Add to shell profiles (avoid duplicates)
add_env_var() {
  local file="$1"
  local line="export SSL_CERT_FILE=$SSL_PATH"
  if [ -f "$file" ]; then
    if ! grep -q "SSL_CERT_FILE" "$file" 2>/dev/null; then
      echo "$line" >> "$file"
      log_ok "Added to $file"
    else
      log_info "Already present in $file"
    fi
  fi
}

add_env_var "$HOME/.bashrc"
add_env_var "$HOME/.profile"
add_env_var "$HOME/.bash_profile"

export SSL_CERT_FILE="$SSL_PATH"
log_ok "SSL environment configured"

# ── Phase 5: Storage Permission ─────────────────────────────────────
current_step="Storage Permission"
log_step "Phase 5: Granting Storage Access"

if [ ! -d "$HOME/storage" ]; then
  log_info "Requesting storage permission..."
  echo -e "${YELLOW}  ⚠  A popup will appear on your screen — tap ALLOW.${NC}"
  sleep 2
  termux-setup-storage
  log_ok "Storage permission granted"
else
  log_info "Storage already accessible at ~/storage/"
fi

# ── Phase 6: Cleanup ────────────────────────────────────────────────
current_step="Cleanup"
log_step "Phase 6: Cleaning Up"

log_info "Removing build directory..."
rm -rf "$BUILD_DIR"
log_ok "Build directory removed"

log_info "Clearing package caches..."
pkg clean
apt autoremove -y
npm cache clean --force
log_ok "Caches cleared"

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║     Installation Complete!              ║${NC}"
echo -e "${GREEN}  ║     OpenCode is ready to use.           ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}→${NC} Navigate to your project:  ${YELLOW}cd ~/storage/downloads${NC}"
echo -e "  ${CYAN}→${NC} Launch OpenCode:            ${YELLOW}opencode${NC}"
echo ""
echo -e "  ${CYAN}→${NC} First time? Run ${YELLOW}opencode${NC} and follow the setup prompts."
echo ""
echo -e "  ${CYAN}→${NC} Need help? ${YELLOW}https://github.com/Radit-lab/opencode-android${NC}"
echo ""
