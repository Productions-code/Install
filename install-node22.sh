#!/usr/bin/env sh
set -eu

# ============================================================================
# install-node22.sh - Advanced Node.js Installer for Linux
# ============================================================================
# Installs Node.js LTS from official Node.js binaries.
#
# Features:
#   - Auto-detect architecture (x64, arm64, armv7l, ppc64le, s390x)
#   - Download from official Node.js release directory
#   - Verify SHA256 via SHASUMS256.txt
#   - Auto-install xz if missing (apt/dnf/yum/pacman/apk/zypper)
#   - Fallback to .tar.gz if xz unavailable
#   - Symlink binaries to /usr/local/bin
#   - Auto-upgrade npm (configurable)
#   - Colored output with verbose mode
#   - Cleanup trap for temp files
#   - Idempotent PATH setup
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-node22.sh)
#   ./install-node22.sh 22
#   ./install-node22.sh 22 22.12.0
#   VERBOSE=1 ./install-node22.sh
#
# Environment Variables:
#   NODE_MAJOR       - Major version (default: 22)
#   NODE_VERSION     - Specific version e.g. "22.12.0" (default: latest)
#   PREFIX           - Installation prefix (default: /usr/local)
#   NPM_VERSION      - npm version to install (default: 11.7.0)
#   AUTO_UPDATE_NPM  - Auto-upgrade npm (default: 1)
#   AUTO_INSTALL_DEPS- Auto-install xz (default: 1)
#   FORCE_TARGZ      - Force tar.gz instead of tar.xz (default: 0)
#   VERBOSE          - Enable verbose output (default: 0)
# ============================================================================

# ===== Config =====
PREFIX="${PREFIX:-/usr/local}"
INSTALL_ROOT="${INSTALL_ROOT:-$PREFIX/lib/nodejs}"
NODE_MAJOR="${1:-22}"
NODE_VERSION="${2:-}"
CHANNEL="${CHANNEL:-latest-v${NODE_MAJOR}.x}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"
FORCE_TARGZ="${FORCE_TARGZ:-0}"
NPM_VERSION="${NPM_VERSION:-11.7.0}"
AUTO_UPDATE_NPM="${AUTO_UPDATE_NPM:-1}"
VERBOSE="${VERBOSE:-0}"

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ===== Temp dir (declare before trap) =====
TMPDIR=""

# ===== Cleanup trap =====
cleanup() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT INT TERM

# ===== Helpers =====
log()         { printf "${CYAN}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_step()    { printf "${BOLD}==> %s${NC}\n" "$*"; }
log_debug()   { [ "$VERBOSE" = "1" ] && printf "${BLUE}[DEBUG]${NC} %s\n" "$*" || true; }

die() { log_error "$*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  need_cmd "$1" || die "Required command '$1' not found. Please install it first."
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    sh -c "$*"
  else
    need_cmd sudo || die "Need sudo to run as root"
    sudo sh -c "$*"
  fi
}

detect_arch() {
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)   echo "x64" ;;
    aarch64|arm64)  echo "arm64" ;;
    armv7l)         echo "armv7l" ;;
    ppc64le)        echo "ppc64le" ;;
    s390x)          echo "s390x" ;;
    riscv64)        echo "riscv64" ;;
    *)              die "Unsupported architecture: $arch" ;;
  esac
}

append_once() {
  file="$1"
  line="$2"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file"
  if ! grep -Fqs "$line" "$file"; then
    echo "$line" >> "$file"
    log_debug "Added to $file: $line"
  else
    log_debug "Already exists in $file: $line"
  fi
}

detect_pkg_mgr() {
  if need_cmd apt-get; then echo "apt"
  elif need_cmd dnf; then echo "dnf"
  elif need_cmd yum; then echo "yum"
  elif need_cmd pacman; then echo "pacman"
  elif need_cmd apk; then echo "apk"
  elif need_cmd zypper; then echo "zypper"
  else echo ""
  fi
}

install_xz_if_missing() {
  if need_cmd xz; then
    return 0
  fi

  [ "$AUTO_INSTALL_DEPS" = "1" ] || die "xz not installed. Install it manually (e.g., apt install xz-utils) and retry."

  pm="$(detect_pkg_mgr)"
  [ -n "$pm" ] || die "xz not installed and package manager not detected. Install xz manually."

  log "xz not found. Installing via $pm..."
  case "$pm" in
    apt)
      as_root "apt-get update -y"
      as_root "apt-get install -y xz-utils"
      ;;
    dnf)
      as_root "dnf install -y xz"
      ;;
    yum)
      as_root "yum install -y xz"
      ;;
    pacman)
      as_root "pacman -Sy --noconfirm xz"
      ;;
    apk)
      as_root "apk add --no-cache xz"
      ;;
    zypper)
      as_root "zypper --non-interactive install xz"
      ;;
    *)
      die "Unsupported package manager: $pm"
      ;;
  esac

  need_cmd xz || die "xz still not available after install. Check package repository."
}

maybe_update_npm() {
  [ "$AUTO_UPDATE_NPM" = "1" ] || return 0
  [ -n "${NPM_VERSION:-}" ] || return 0

  NPM_BIN="$PREFIX/bin/npm"
  NODE_BIN="$PREFIX/bin/node"

  [ -x "$NODE_BIN" ] || die "node not found at $NODE_BIN"
  [ -x "$NPM_BIN" ] || die "npm not found at $NPM_BIN"

  current="$("$NPM_BIN" -v 2>/dev/null || true)"
  if [ "$current" = "$NPM_VERSION" ]; then
    log "npm already at version $NPM_VERSION"
    return 0
  fi

  log_step "Updating npm: ${current:-unknown} -> $NPM_VERSION"
  if [ "$(id -u)" -eq 0 ]; then
    "$NPM_BIN" install -g "npm@${NPM_VERSION}"
  else
    need_cmd sudo || die "Need sudo to update npm globally"
    sudo "$NPM_BIN" install -g "npm@${NPM_VERSION}"
  fi

  log_success "npm updated to $("$NPM_BIN" -v)"
}

pick_filename() {
  ext="$1"
  # Escape dots in extension for grep
  grep " node-v.*-linux-${ARCH}\.${ext}$" "$TMPDIR/SHASUMS256.txt" | awk '{print $2}' | head -n1 || true
}

# ===== Main function =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              Node.js Installer for Linux                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  # Pre-flight checks
  require_cmd curl
  require_cmd tar
  require_cmd sha256sum
  require_cmd awk
  require_cmd grep
  require_cmd sed

  # Detect architecture
  ARCH="$(detect_arch)"
  log_debug "Detected architecture: $ARCH"

  # Linux-only check
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  [ "$OS" = "linux" ] || die "This script is for Linux only. Detected OS: $OS"

  # Create temp directory
  TMPDIR="$(mktemp -d)"
  log_debug "Temp directory: $TMPDIR"

  # Determine extension
  EXT="tar.xz"
  [ "$FORCE_TARGZ" = "1" ] && EXT="tar.gz"

  # Build base URL
  if [ -n "$NODE_VERSION" ]; then
    BASE_URL="https://nodejs.org/download/release/v${NODE_VERSION}"
  else
    BASE_URL="https://nodejs.org/download/release/${CHANNEL}"
  fi

  log "Node.js major: v$NODE_MAJOR"
  log "Channel: $CHANNEL"
  log "Install prefix: $PREFIX"
  log_debug "Base URL: $BASE_URL"
  echo ""

  # Download SHASUMS256.txt
  log_step "Downloading SHASUMS256.txt"
  if ! curl -fL "$BASE_URL/SHASUMS256.txt" -o "$TMPDIR/SHASUMS256.txt"; then
    die "Failed to download SHASUMS256.txt from $BASE_URL"
  fi
  log_success "SHASUMS256.txt downloaded"

  # Determine tarball filename
  if [ -n "$NODE_VERSION" ]; then
    FILENAME="node-v${NODE_VERSION}-linux-${ARCH}.${EXT}"
  else
    FILENAME="$(pick_filename "$EXT")"
  fi

  # Fallback to tar.gz if tar.xz not available
  if [ -z "$FILENAME" ] || ! grep -q " $FILENAME$" "$TMPDIR/SHASUMS256.txt"; then
    if [ "$EXT" = "tar.xz" ]; then
      log "tar.xz not available for linux-$ARCH, falling back to tar.gz"
      EXT="tar.gz"
      if [ -n "$NODE_VERSION" ]; then
        FILENAME="node-v${NODE_VERSION}-linux-${ARCH}.tar.gz"
      else
        FILENAME="$(pick_filename "tar.gz")"
      fi
    fi
  fi

  [ -n "$FILENAME" ] || die "No matching tarball found for linux-$ARCH. Check: $BASE_URL/"

  log "Tarball: $FILENAME"

  # Download tarball
  log_step "Downloading tarball"
  if ! curl -fL --progress-bar "$BASE_URL/$FILENAME" -o "$TMPDIR/$FILENAME"; then
    die "Failed to download tarball"
  fi
  log_success "Download complete: $(du -h "$TMPDIR/$FILENAME" | awk '{print $1}')"

  # Verify SHA256
  log_step "Verifying SHA256 checksum"
  grep " $FILENAME$" "$TMPDIR/SHASUMS256.txt" > "$TMPDIR/SHASUMS256.one"
  (cd "$TMPDIR" && sha256sum -c SHASUMS256.one > /dev/null 2>&1)
  log_success "SHA256 checksum verified"

  # Ensure xz is available if needed
  if [ "$EXT" = "tar.xz" ]; then
    install_xz_if_missing
  fi

  # Install
  as_root "mkdir -p '$INSTALL_ROOT'"

  NODE_FOLDER="$(echo "$FILENAME" | sed 's/\.tar\.xz$//; s/\.tar\.gz$//')"

  log_step "Extracting to $INSTALL_ROOT"
  as_root "rm -rf '$INSTALL_ROOT/$NODE_FOLDER'"

  if [ "$EXT" = "tar.xz" ]; then
    as_root "tar -C '$INSTALL_ROOT' -xJf '$TMPDIR/$FILENAME'"
  else
    as_root "tar -C '$INSTALL_ROOT' -xzf '$TMPDIR/$FILENAME'"
  fi
  log_success "Extraction complete"

  # Create symlinks
  log_step "Creating symlinks"
  as_root "ln -sfn '$INSTALL_ROOT/$NODE_FOLDER' '$PREFIX/node'"

  as_root "mkdir -p '$PREFIX/bin'"
  for bin in node npm npx corepack; do
    if [ -f "$PREFIX/node/bin/$bin" ]; then
      as_root "ln -sfn '$PREFIX/node/bin/$bin' '$PREFIX/bin/$bin'"
      log_debug "Symlinked: $bin"
    fi
  done
  log_success "Symlinks created"

  # Setup PATH
  log_step "Setting up PATH"
  EXPORT_LINE="export PATH=\"$PREFIX/bin:\$PATH\""

  if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || need_cmd zsh; then
    append_once "$HOME/.zprofile" "$EXPORT_LINE"
    append_once "$HOME/.zshrc" "$EXPORT_LINE"
    SHELL_RC="~/.zshrc"
  else
    append_once "$HOME/.profile" "$EXPORT_LINE"
    SHELL_RC="~/.profile"
  fi
  log_success "PATH configured"

  # Enable corepack
  if [ -x "$PREFIX/bin/corepack" ]; then
    "$PREFIX/bin/corepack" enable >/dev/null 2>&1 || true
    log_debug "Corepack enabled"
  fi

  # Update npm
  maybe_update_npm

  # Verification
  echo ""
  log_step "Verifying installation"
  echo "────────────────────────────────────────────────────────────────"
  echo "node: $("$PREFIX/bin/node" -v)"
  echo "npm:  $("$PREFIX/bin/npm" -v)"
  echo "path: $(command -v node || echo "$PREFIX/bin/node")"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  log_success "Node.js installed successfully!"
  echo ""
  log "To activate now, run:"
  echo "  source $SHELL_RC"
  echo ""
  log "Or open a new terminal."
}

# Run main
main "$@"
