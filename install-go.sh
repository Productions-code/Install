#!/usr/bin/env sh
set -eu

# ============================================================================
# install-go.sh - Advanced Go (Golang) Installer for Linux
# ============================================================================
# Features:
#   - Auto-detect architecture (amd64, arm64, 386, armv6l)
#   - SHA256 checksum verification
#   - Auto-detect latest Go version if not specified
#   - Cleanup trap for temp files
#   - Verbose/debug mode
#   - Idempotent PATH setup (zsh/bash/profile)
#   - Colored output for better UX
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-go.sh)
#   GO_VERSION=1.22.5 ./install-go.sh
#   ./install-go.sh 1.22.5
#   VERBOSE=1 ./install-go.sh
#
# Environment Variables:
#   GO_VERSION  - Go version to install (default: auto-detect latest)
#   PREFIX      - Installation prefix (default: /usr/local)
#   VERBOSE     - Enable verbose output (default: 0)
# ============================================================================

# ===== Config =====
GO_VERSION="${1:-${GO_VERSION:-}}"
PREFIX="${PREFIX:-/usr/local}"
GO_DIR="$PREFIX/go"
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
    x86_64|amd64)   echo "amd64" ;;
    aarch64|arm64)  echo "arm64" ;;
    i386|i686)      echo "386" ;;
    armv6l)         echo "armv6l" ;;
    armv7l)         echo "armv6l" ;;  # Go uses armv6l for 32-bit ARM
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

get_latest_go_version() {
  log "Fetching latest Go version from go.dev..."
  version=$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -n1 | sed 's/^go//')
  if [ -z "$version" ]; then
    die "Failed to fetch latest Go version"
  fi
  echo "$version"
}

# ===== Main function =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              Go (Golang) Installer for Linux                 ║"
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
  if [ "$OS" != "linux" ]; then
    die "This script is for Linux only. Detected OS: $OS"
  fi

  # Auto-detect version if not specified
  if [ -z "$GO_VERSION" ]; then
    GO_VERSION="$(get_latest_go_version)"
  fi

  log "Go version: $GO_VERSION"
  log "Install prefix: $PREFIX"
  echo ""

  # Create temp directory
  TMPDIR="$(mktemp -d)"
  log_debug "Temp directory: $TMPDIR"

  # Build download URL
  TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
  BASE_URL="https://go.dev/dl"
  URL="${BASE_URL}/${TARBALL}"
  CHECKSUM_URL="${BASE_URL}/${TARBALL}.sha256"

  log_step "Downloading tarball"
  log_debug "URL: $URL"
  TMP_TARBALL="$TMPDIR/$TARBALL"
  if ! curl -fL --progress-bar "$URL" -o "$TMP_TARBALL"; then
    die "Failed to download tarball from $URL"
  fi
  log_success "Download complete: $(du -h "$TMP_TARBALL" | awk '{print $1}')"

  # Verify SHA256 checksum
  log_step "Verifying SHA256 checksum"
  TMP_SHA256="$TMPDIR/checksum.sha256"

  if curl -fsSL "$CHECKSUM_URL" -o "$TMP_SHA256" 2>/dev/null; then
    EXPECTED_HASH="$(awk '{print $1}' "$TMP_SHA256")"
    ACTUAL_HASH="$(sha256sum "$TMP_TARBALL" | awk '{print $1}')"

    log_debug "Expected: $EXPECTED_HASH"
    log_debug "Actual:   $ACTUAL_HASH"

    if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
      die "SHA256 checksum mismatch! Expected: $EXPECTED_HASH, Got: $ACTUAL_HASH"
    fi
    log_success "SHA256 checksum verified"
  else
    log_warn "Could not download checksum file. Proceeding without verification..."
  fi

  # Remove old Go installation
  if [ -d "$GO_DIR" ]; then
    log_step "Removing old Go installation"
    as_root "rm -rf '$GO_DIR'"
  fi

  # Extract
  log_step "Extracting to $PREFIX"
  as_root "tar -C '$PREFIX' -xzf '$TMP_TARBALL'"
  log_success "Extraction complete"

  # Setup PATH - use PREFIX variable, not hardcoded
  log_step "Setting up PATH"
  EXPORT_PATH="export PATH=\"\$PATH:$PREFIX/go/bin:\$HOME/go/bin\""
  EXPORT_GOPATH='export GOPATH="$HOME/go"'

  if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || need_cmd zsh; then
    append_once "$HOME/.zprofile" "$EXPORT_PATH"
    append_once "$HOME/.zprofile" "$EXPORT_GOPATH"
    append_once "$HOME/.zshrc" "$EXPORT_PATH"
    append_once "$HOME/.zshrc" "$EXPORT_GOPATH"
    SHELL_RC="~/.zshrc"
  else
    append_once "$HOME/.profile" "$EXPORT_PATH"
    append_once "$HOME/.profile" "$EXPORT_GOPATH"
    if [ -f "$HOME/.bashrc" ]; then
      append_once "$HOME/.bashrc" "$EXPORT_PATH"
      append_once "$HOME/.bashrc" "$EXPORT_GOPATH"
    fi
    SHELL_RC="~/.profile"
  fi
  log_success "PATH configured"

  # Create GOPATH directories
  mkdir -p "$HOME/go/bin" "$HOME/go/src" "$HOME/go/pkg"
  log_debug "GOPATH directories created"

  # Verification
  echo ""
  log_step "Verifying installation"
  echo "────────────────────────────────────────────────────────────────"
  "$GO_DIR/bin/go" version
  echo "GOROOT: $GO_DIR"
  echo "GOPATH: \$HOME/go"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  log_success "Go $GO_VERSION installed successfully!"
  echo ""
  log "To activate now, run:"
  echo "  source $SHELL_RC"
  echo ""
  log "Or open a new terminal."
}

# Run main
main "$@"
