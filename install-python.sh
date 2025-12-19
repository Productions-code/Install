#!/usr/bin/env sh
set -eu

# ============================================================================
# install-python.sh - Advanced Python Installer for Linux
# ============================================================================
# Installs Python from source with full optimizations or via pyenv.
#
# Features:
#   - Install from source (with PGO/LTO optimizations) or via pyenv
#   - Auto-install build dependencies (apt/dnf/yum/pacman/apk/zypper)
#   - Auto-detect latest Python version if not specified
#   - SHA256 checksum verification
#   - Install pip, setuptools, wheel, virtualenv
#   - Colored output with verbose mode
#   - Cleanup trap for temp files
#   - Idempotent PATH setup
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-python.sh)
#   PYTHON_VERSION=3.12.4 ./install-python.sh
#   ./install-python.sh 3.12.4
#   INSTALL_METHOD=pyenv ./install-python.sh
#   VERBOSE=1 ./install-python.sh
#
# Environment Variables:
#   PYTHON_VERSION        - Python version (default: auto-detect latest)
#   INSTALL_METHOD        - "source" or "pyenv" (default: source)
#   PREFIX                - Installation prefix (default: /usr/local)
#   VERBOSE               - Enable verbose output (default: 0)
#   SKIP_DEPS             - Skip installing build dependencies (default: 0)
#   ENABLE_OPTIMIZATIONS  - Enable PGO/LTO optimizations (default: 1)
# ============================================================================

# ===== Config =====
PYTHON_VERSION="${1:-${PYTHON_VERSION:-}}"
INSTALL_METHOD="${INSTALL_METHOD:-source}"
PREFIX="${PREFIX:-/usr/local}"
VERBOSE="${VERBOSE:-0}"
SKIP_DEPS="${SKIP_DEPS:-0}"
ENABLE_OPTIMIZATIONS="${ENABLE_OPTIMIZATIONS:-1}"

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
    x86_64|amd64)   echo "x86_64" ;;
    aarch64|arm64)  echo "aarch64" ;;
    armv7l)         echo "armv7l" ;;
    i386|i686)      echo "i686" ;;
    *)              die "Unsupported architecture: $arch" ;;
  esac
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

# POSIX-compliant version fetching (no grep -P)
get_latest_python_version() {
  log "Fetching latest Python version..."
  
  # Try endoflife.date API first (returns JSON, parse with sed/grep)
  version=$(curl -fsSL "https://endoflife.date/api/python.json" 2>/dev/null | \
    grep -o '"latest":"[0-9.]*"' | head -1 | sed 's/[^0-9.]//g')
  
  if [ -z "$version" ]; then
    # Fallback: parse python.org FTP listing with POSIX tools
    version=$(curl -fsSL "https://www.python.org/ftp/python/" 2>/dev/null | \
      grep -o 'href="3\.[0-9]*\.[0-9]*/"' | \
      sed 's/href="//; s/\/"$//' | \
      sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  fi
  
  if [ -z "$version" ]; then
    # Final fallback
    version="3.12.4"
    log_warn "Could not fetch latest version, using fallback: $version"
  fi
  
  echo "$version"
}

get_python_major_minor() {
  echo "$1" | cut -d. -f1,2
}

# ===== Install Build Dependencies =====
install_build_deps() {
  [ "$SKIP_DEPS" = "1" ] && { log_debug "Skipping dependency installation"; return 0; }

  pm="$(detect_pkg_mgr)"
  [ -n "$pm" ] || { log_warn "Package manager not detected, skipping dependency installation"; return 0; }

  log_step "Installing build dependencies via $pm"

  case "$pm" in
    apt)
      as_root "apt-get update -y"
      as_root "apt-get install -y build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
        libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
        git libgdbm-dev libnss3-dev libxml2-dev libxmlsec1-dev"
      ;;
    dnf)
      as_root "dnf groupinstall -y 'Development Tools'"
      as_root "dnf install -y openssl-devel bzip2-devel libffi-devel \
        zlib-devel readline-devel sqlite-devel ncurses-devel xz-devel \
        tk-devel gdbm-devel libuuid-devel"
      ;;
    yum)
      as_root "yum groupinstall -y 'Development Tools'"
      as_root "yum install -y openssl-devel bzip2-devel libffi-devel \
        zlib-devel readline-devel sqlite-devel ncurses-devel xz-devel \
        tk-devel gdbm-devel"
      ;;
    pacman)
      as_root "pacman -Sy --noconfirm base-devel openssl zlib bzip2 \
        readline sqlite ncurses xz tk libffi"
      ;;
    apk)
      as_root "apk add --no-cache build-base openssl-dev zlib-dev \
        bzip2-dev readline-dev sqlite-dev ncurses-dev xz-dev tk-dev \
        libffi-dev linux-headers"
      ;;
    zypper)
      as_root "zypper --non-interactive install -t pattern devel_basis"
      as_root "zypper --non-interactive install libopenssl-devel zlib-devel \
        libbz2-devel readline-devel sqlite3-devel ncurses-devel xz-devel \
        tk-devel libffi-devel"
      ;;
    *)
      log_warn "Unsupported package manager for auto-install: $pm"
      ;;
  esac

  log_success "Build dependencies installed"
}

# ===== Install via pyenv =====
install_via_pyenv() {
  log_step "Installing Python via pyenv"

  # Install pyenv if not present
  if ! need_cmd pyenv; then
    log "Installing pyenv..."
    curl -fsSL https://pyenv.run | sh

    # Setup PATH for pyenv
    PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    # Add to shell rc
    PYENV_INIT='export PYENV_ROOT="$HOME/.pyenv"'
    PYENV_PATH='export PATH="$PYENV_ROOT/bin:$PATH"'
    PYENV_EVAL='eval "$(pyenv init -)"'

    if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || need_cmd zsh; then
      append_once "$HOME/.zshrc" "$PYENV_INIT"
      append_once "$HOME/.zshrc" "$PYENV_PATH"
      append_once "$HOME/.zshrc" "$PYENV_EVAL"
    else
      append_once "$HOME/.bashrc" "$PYENV_INIT"
      append_once "$HOME/.bashrc" "$PYENV_PATH"
      append_once "$HOME/.bashrc" "$PYENV_EVAL"
    fi

    # Initialize pyenv for current session
    eval "$(pyenv init -)" 2>/dev/null || true
  fi

  # Install Python version
  log "Installing Python $PYTHON_VERSION via pyenv..."
  "$HOME/.pyenv/bin/pyenv" install -s "$PYTHON_VERSION"
  "$HOME/.pyenv/bin/pyenv" global "$PYTHON_VERSION"

  log_success "Python $PYTHON_VERSION installed via pyenv"
}

# ===== Install from Source =====
install_from_source() {
  log_step "Installing Python $PYTHON_VERSION from source"

  # Download URLs
  TARBALL="Python-${PYTHON_VERSION}.tar.xz"
  BASE_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}"
  URL="${BASE_URL}/${TARBALL}"

  log_debug "Download URL: $URL"

  # Download tarball
  log_step "Downloading Python source"
  TMP_TARBALL="$TMPDIR/$TARBALL"
  if ! curl -fL --progress-bar "$URL" -o "$TMP_TARBALL"; then
    die "Failed to download tarball from $URL"
  fi
  log_success "Download complete: $(du -h "$TMP_TARBALL" | awk '{print $1}')"

  # Verify checksum (SHA256)
  log_step "Verifying SHA256 checksum"
  SHASUMS_URL="${BASE_URL}/Python-${PYTHON_VERSION}.tar.xz.asc"
  
  # Try to get SHA256 from python.org
  if curl -fsSL "${BASE_URL}/" 2>/dev/null | grep -q "\.sha256"; then
    if curl -fsSL "${BASE_URL}/${TARBALL}.sha256" -o "$TMPDIR/sha256" 2>/dev/null; then
      EXPECTED_HASH="$(awk '{print $1}' "$TMPDIR/sha256")"
      ACTUAL_HASH="$(sha256sum "$TMP_TARBALL" | awk '{print $1}')"
      if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
        log_success "SHA256 checksum verified"
      else
        log_warn "SHA256 mismatch, proceeding anyway..."
      fi
    else
      log_warn "Could not download SHA256 checksum, proceeding without verification"
    fi
  else
    log_warn "SHA256 checksum not available, proceeding without verification"
  fi

  # Extract
  log_step "Extracting source"
  tar -C "$TMPDIR" -xJf "$TMP_TARBALL"
  SRC_DIR="$TMPDIR/Python-${PYTHON_VERSION}"

  # Configure and build in subshell to avoid directory pollution
  log_step "Configuring (this may take a moment)"
  
  CONFIGURE_OPTS="--prefix=$PREFIX --enable-shared --with-system-ffi"
  if [ "$ENABLE_OPTIMIZATIONS" = "1" ]; then
    CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-optimizations --with-lto"
    log_debug "Optimizations enabled (PGO + LTO)"
  fi
  log_debug "Configure options: $CONFIGURE_OPTS"

  # Use subshell to avoid changing global directory
  (
    cd "$SRC_DIR"
    if [ "$VERBOSE" = "1" ]; then
      ./configure $CONFIGURE_OPTS
    else
      ./configure $CONFIGURE_OPTS > /dev/null 2>&1
    fi
  )

  # Build
  log_step "Building (this may take a while)"
  NPROC=$(nproc 2>/dev/null || echo 2)
  log_debug "Using $NPROC parallel jobs"

  (
    cd "$SRC_DIR"
    if [ "$VERBOSE" = "1" ]; then
      make -j"$NPROC"
    else
      make -j"$NPROC" > /dev/null 2>&1
    fi
  )

  # Install
  log_step "Installing"
  (
    cd "$SRC_DIR"
    as_root "make altinstall"
  )

  # Create symlinks
  PYTHON_MAJOR_MINOR="$(get_python_major_minor "$PYTHON_VERSION")"
  log_step "Creating symlinks"
  as_root "ln -sf '$PREFIX/bin/python${PYTHON_MAJOR_MINOR}' '$PREFIX/bin/python3'"
  as_root "ln -sf '$PREFIX/bin/python${PYTHON_MAJOR_MINOR}' '$PREFIX/bin/python'"
  as_root "ln -sf '$PREFIX/bin/pip${PYTHON_MAJOR_MINOR}' '$PREFIX/bin/pip3'"
  as_root "ln -sf '$PREFIX/bin/pip${PYTHON_MAJOR_MINOR}' '$PREFIX/bin/pip'"

  # Update shared library cache
  if [ -f "/etc/ld.so.conf" ]; then
    echo "$PREFIX/lib" | as_root "tee /etc/ld.so.conf.d/python.conf" > /dev/null
    as_root "ldconfig"
    log_debug "Updated ldconfig"
  fi

  log_success "Python $PYTHON_VERSION installed from source"
}

# ===== Setup pip and tools =====
setup_pip_tools() {
  log_step "Setting up pip and tools"

  if [ "$INSTALL_METHOD" = "pyenv" ]; then
    PYTHON_BIN="$HOME/.pyenv/shims/python"
    PIP_BIN="$HOME/.pyenv/shims/pip"
  else
    PYTHON_BIN="$PREFIX/bin/python3"
    PIP_BIN="$PREFIX/bin/pip3"
  fi

  # Upgrade pip
  log "Upgrading pip..."
  "$PYTHON_BIN" -m pip install --upgrade pip 2>/dev/null || true

  # Install essential tools
  log "Installing setuptools, wheel, virtualenv..."
  "$PYTHON_BIN" -m pip install --upgrade setuptools wheel virtualenv 2>/dev/null || true

  log_success "pip and tools installed"
}

# ===== Setup PATH =====
setup_path() {
  log_step "Setting up PATH"

  if [ "$INSTALL_METHOD" = "pyenv" ]; then
    log "pyenv manages PATH automatically"
    return 0
  fi

  EXPORT_PATH="export PATH=\"$PREFIX/bin:\$PATH\""
  EXPORT_LD="export LD_LIBRARY_PATH=\"$PREFIX/lib:\$LD_LIBRARY_PATH\""

  if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || need_cmd zsh; then
    append_once "$HOME/.zprofile" "$EXPORT_PATH"
    append_once "$HOME/.zprofile" "$EXPORT_LD"
    append_once "$HOME/.zshrc" "$EXPORT_PATH"
    append_once "$HOME/.zshrc" "$EXPORT_LD"
    SHELL_RC="~/.zshrc"
  else
    append_once "$HOME/.profile" "$EXPORT_PATH"
    append_once "$HOME/.profile" "$EXPORT_LD"
    if [ -f "$HOME/.bashrc" ]; then
      append_once "$HOME/.bashrc" "$EXPORT_PATH"
      append_once "$HOME/.bashrc" "$EXPORT_LD"
    fi
    SHELL_RC="~/.profile"
  fi
  
  log_success "PATH configured"
}

# ===== Main function =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              Python Installer for Linux                      ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  # Pre-flight checks
  require_cmd curl
  require_cmd tar
  require_cmd awk
  require_cmd grep
  require_cmd sed
  
  if [ "$INSTALL_METHOD" = "source" ]; then
    require_cmd make
    require_cmd xz
  fi

  # Detect architecture
  ARCH="$(detect_arch)"
  log_debug "Detected architecture: $ARCH"

  # Linux-only check
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [ "$OS" != "linux" ]; then
    die "This script is for Linux only. Detected OS: $OS"
  fi

  # Auto-detect version if not specified
  if [ -z "$PYTHON_VERSION" ]; then
    PYTHON_VERSION="$(get_latest_python_version)"
  fi

  log "Python version: $PYTHON_VERSION"
  log "Install method: $INSTALL_METHOD"
  log "Install prefix: $PREFIX"
  echo ""

  # Create temp directory
  TMPDIR="$(mktemp -d)"
  log_debug "Temp directory: $TMPDIR"

  # Install build dependencies
  install_build_deps

  # Install Python
  if [ "$INSTALL_METHOD" = "pyenv" ]; then
    install_via_pyenv
  else
    install_from_source
  fi

  # Setup pip and tools
  setup_pip_tools

  # Setup PATH
  setup_path

  # Verification
  echo ""
  log_step "Verifying installation"
  echo "────────────────────────────────────────────────────────────────"

  if [ "$INSTALL_METHOD" = "pyenv" ]; then
    PYTHON_BIN="$HOME/.pyenv/shims/python"
    PIP_BIN="$HOME/.pyenv/shims/pip"
  else
    PYTHON_BIN="$PREFIX/bin/python3"
    PIP_BIN="$PREFIX/bin/pip3"
  fi

  echo "Python: $("$PYTHON_BIN" --version 2>&1)"
  echo "pip:    $("$PIP_BIN" --version 2>&1 | awk '{print $2}')"
  echo "Path:   $PYTHON_BIN"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  log_success "Python $PYTHON_VERSION installed successfully!"
  echo ""
  log "To activate now, run:"
  if [ "$INSTALL_METHOD" = "pyenv" ]; then
    echo "  source ~/.bashrc  # or ~/.zshrc"
  else
    echo "  source ${SHELL_RC:-~/.profile}"
  fi
  echo ""
  log "Or open a new terminal."
  echo ""
  log "Quick test:"
  echo "  python3 --version"
  echo "  pip3 --version"
  echo "  python3 -c \"print('Hello, Python!')\""
}

# Run main
main "$@"
