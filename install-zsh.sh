#!/usr/bin/env sh
set -eu

# ============================================================================
# install-zsh.sh - Advanced Zsh Environment Installer for Linux
# ============================================================================
# Installs Zsh with zinit plugin manager, powerlevel10k theme, and useful
# plugins for a modern shell experience.
#
# Features:
#   - Install Zsh and set as default shell
#   - Install dependencies (fzf, fd, eza, git, curl)
#   - Download pre-configured .zshrc
#   - Setup Zinit plugin manager (auto-installs on first zsh launch)
#   - Configure NVM integration
#   - Precompile for performance
#   - Multi-distro support (apt/dnf/yum/pacman/apk/zypper)
#
# Components installed:
#   - Zinit (plugin manager)
#   - Powerlevel10k (theme)
#   - zsh-syntax-highlighting
#   - zsh-completions
#   - zsh-autosuggestions
#   - zsh-autocomplete
#   - fzf (fuzzy finder)
#   - z/fasd/autojump (directory jumping)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-zsh.sh)
#   ZSH_USER=myuser bash <(curl -fsSL ...)
#   VERBOSE=1 ./install-zsh.sh
#
# Environment Variables:
#   ZSH_USER     - User to configure (default: current user or reza)
#   VERBOSE      - Enable verbose output (default: 0)
#   SKIP_DEPS    - Skip installing dependencies (default: 0)
#   SKIP_SHELL   - Skip changing default shell (default: 0)
# ============================================================================

# ===== Config =====
ZSH_USER="${ZSH_USER:-${SUDO_USER:-${USER:-reza}}}"
ZSH_HOME="${ZSH_HOME:-/home/$ZSH_USER}"
VERBOSE="${VERBOSE:-0}"
SKIP_DEPS="${SKIP_DEPS:-0}"
SKIP_SHELL="${SKIP_SHELL:-0}"

# URLs
ZSHRC_URL="https://github.com/Productions-code/Install/releases/download/0.0.1/default.zshrc"

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

as_user() {
  if [ "$(id -u)" -eq 0 ]; then
    su - "$ZSH_USER" -c "$*"
  else
    sh -c "$*"
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

# ===== Install Zsh =====
install_zsh() {
  log_step "Installing Zsh"

  if need_cmd zsh; then
    log "Zsh already installed: $(zsh --version)"
    return 0
  fi

  pm="$(detect_pkg_mgr)"
  [ -n "$pm" ] || die "Package manager not detected"

  case "$pm" in
    apt)
      as_root "apt-get update -y"
      as_root "apt-get install -y zsh"
      ;;
    dnf)
      as_root "dnf install -y zsh"
      ;;
    yum)
      as_root "yum install -y zsh"
      ;;
    pacman)
      as_root "pacman -Sy --noconfirm zsh"
      ;;
    apk)
      as_root "apk add --no-cache zsh"
      ;;
    zypper)
      as_root "zypper --non-interactive install zsh"
      ;;
    *)
      die "Unsupported package manager: $pm"
      ;;
  esac

  log_success "Zsh installed: $(zsh --version)"
}

# ===== Install Dependencies =====
install_dependencies() {
  [ "$SKIP_DEPS" = "1" ] && { log "Skipping dependency installation"; return 0; }

  log_step "Installing dependencies"

  pm="$(detect_pkg_mgr)"
  [ -n "$pm" ] || { log_warn "Package manager not detected, skipping deps"; return 0; }

  case "$pm" in
    apt)
      as_root "apt-get update -y"
      as_root "apt-get install -y git curl wget fzf fd-find eza unzip fontconfig"
      # Create fd symlink (Debian/Ubuntu uses fdfind)
      if [ -x /usr/bin/fdfind ] && [ ! -x /usr/bin/fd ]; then
        as_root "ln -sf /usr/bin/fdfind /usr/bin/fd"
      fi
      ;;
    dnf)
      as_root "dnf install -y git curl wget fzf fd-find eza unzip fontconfig"
      ;;
    yum)
      as_root "yum install -y git curl wget unzip fontconfig"
      # fzf and eza may need manual install on older systems
      ;;
    pacman)
      as_root "pacman -Sy --noconfirm git curl wget fzf fd eza unzip ttf-meslo-nerd"
      ;;
    apk)
      as_root "apk add --no-cache git curl wget fzf fd eza unzip font-noto"
      ;;
    zypper)
      as_root "zypper --non-interactive install git curl wget fzf fd eza unzip"
      ;;
    *)
      log_warn "Unsupported package manager for deps: $pm"
      ;;
  esac

  log_success "Dependencies installed"
}

# ===== Install Nerd Fonts =====
install_fonts() {
  log_step "Installing Nerd Fonts (MesloLGS NF)"

  FONT_DIR="$ZSH_HOME/.local/share/fonts"
  mkdir -p "$FONT_DIR"

  # MesloLGS NF fonts for Powerlevel10k
  FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
  FONTS="MesloLGS%20NF%20Regular.ttf MesloLGS%20NF%20Bold.ttf MesloLGS%20NF%20Italic.ttf MesloLGS%20NF%20Bold%20Italic.ttf"

  for font in $FONTS; do
    if [ ! -f "$FONT_DIR/$(echo "$font" | sed 's/%20/ /g')" ]; then
      curl -fsSL "$FONT_BASE/$font" -o "$FONT_DIR/$(echo "$font" | sed 's/%20/ /g')" 2>/dev/null || true
    fi
  done

  # Update font cache
  if need_cmd fc-cache; then
    fc-cache -f "$FONT_DIR" 2>/dev/null || true
  fi

  # Fix ownership
  as_root "chown -R $ZSH_USER:$ZSH_USER '$FONT_DIR'" 2>/dev/null || true

  log_success "Nerd fonts installed"
}

# ===== Download .zshrc =====
download_zshrc() {
  log_step "Downloading .zshrc configuration"

  ZSHRC_FILE="$ZSH_HOME/.zshrc"

  # Backup existing
  if [ -f "$ZSHRC_FILE" ]; then
    log "Backing up existing .zshrc"
    cp "$ZSHRC_FILE" "${ZSHRC_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  fi

  # Download
  log "Downloading from: $ZSHRC_URL"
  if curl -fsSL "$ZSHRC_URL" -o "$ZSHRC_FILE"; then
    log_success ".zshrc downloaded"
  else
    die "Failed to download .zshrc"
  fi

  # Fix ownership
  as_root "chown $ZSH_USER:$ZSH_USER '$ZSHRC_FILE'"
}

# ===== Create p10k config =====
create_p10k_config() {
  log_step "Creating Powerlevel10k configuration"

  P10K_FILE="$ZSH_HOME/.p10k.zsh"

  if [ -f "$P10K_FILE" ]; then
    log "p10k.zsh already exists"
    return 0
  fi

  # Create minimal p10k config (user can customize later with p10k configure)
  cat > "$P10K_FILE" << 'EOF'
# Powerlevel10k configuration
# Run 'p10k configure' for interactive setup

# Instant prompt mode
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Basic prompt elements
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  os_icon dir vcs newline prompt_char
)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status command_execution_time background_jobs time
)

# Directory
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=30

# Colors
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=255
typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=178

# Prompt character
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196

# Transient prompt
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
EOF

  as_root "chown $ZSH_USER:$ZSH_USER '$P10K_FILE'"
  log_success "p10k.zsh created"
}

# ===== Setup NVM =====
setup_nvm() {
  log_step "Setting up NVM integration"

  NVM_DIR="$ZSH_HOME/.nvm"
  ZSHRC_FILE="$ZSH_HOME/.zshrc"

  # Check if NVM lines already in .zshrc
  if grep -q 'NVM_DIR=.*\.nvm' "$ZSHRC_FILE" 2>/dev/null; then
    log "NVM already configured in .zshrc"
    return 0
  fi

  # Add NVM loading to .zshrc
  cat >> "$ZSHRC_FILE" << 'EOF'

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF

  as_root "chown $ZSH_USER:$ZSH_USER '$ZSHRC_FILE'"
  log_success "NVM integration added"
}

# ===== Set Default Shell =====
set_default_shell() {
  [ "$SKIP_SHELL" = "1" ] && { log "Skipping default shell change"; return 0; }

  log_step "Setting Zsh as default shell for $ZSH_USER"

  ZSH_BIN="$(command -v zsh)"
  if [ -z "$ZSH_BIN" ]; then
    log_warn "Zsh not found, skipping shell change"
    return 0
  fi

  # Check current shell
  current_shell="$(getent passwd "$ZSH_USER" 2>/dev/null | awk -F: '{print $7}')" || true

  if [ "$current_shell" = "$ZSH_BIN" ]; then
    log "Zsh already default shell for $ZSH_USER"
    return 0
  fi

  # Ensure zsh is in /etc/shells
  if ! grep -q "^${ZSH_BIN}$" /etc/shells 2>/dev/null; then
    echo "$ZSH_BIN" | as_root "tee -a /etc/shells" > /dev/null
  fi

  # Change shell
  as_root "chsh -s '$ZSH_BIN' '$ZSH_USER'" || log_warn "chsh failed (non-fatal)"

  log_success "Default shell set to Zsh"
}

# ===== Create Zsh directories =====
create_directories() {
  log_step "Creating Zsh directories"

  mkdir -p "$ZSH_HOME/.cache"
  mkdir -p "$ZSH_HOME/.local/share/zinit"
  mkdir -p "$ZSH_HOME/.local/bin"

  as_root "chown -R $ZSH_USER:$ZSH_USER '$ZSH_HOME/.cache'" 2>/dev/null || true
  as_root "chown -R $ZSH_USER:$ZSH_USER '$ZSH_HOME/.local'" 2>/dev/null || true

  log_success "Directories created"
}

# ===== Precompile Zsh files =====
precompile_zsh() {
  log_step "Precompiling Zsh configuration"

  if ! need_cmd zsh; then
    log_warn "Zsh not found, skipping precompile"
    return 0
  fi

  # Compile .zshrc and .p10k.zsh for faster loading
  as_user "zsh -c '[ -f ~/.zshrc ] && zcompile ~/.zshrc || true'" 2>/dev/null || true
  as_user "zsh -c '[ -f ~/.p10k.zsh ] && zcompile ~/.p10k.zsh || true'" 2>/dev/null || true

  log_success "Precompilation complete"
}

# ===== Verify Installation =====
verify_installation() {
  log_step "Verifying installation"

  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "Zsh Environment Installation Summary"
  echo "────────────────────────────────────────────────────────────────"

  # Zsh version
  if need_cmd zsh; then
    echo "Zsh:          $(zsh --version)"
  else
    echo "Zsh:          NOT INSTALLED"
  fi

  # Check files
  [ -f "$ZSH_HOME/.zshrc" ] && echo ".zshrc:       EXISTS" || echo ".zshrc:       MISSING"
  [ -f "$ZSH_HOME/.p10k.zsh" ] && echo ".p10k.zsh:    EXISTS" || echo ".p10k.zsh:    MISSING"

  # Default shell
  current_shell="$(getent passwd "$ZSH_USER" 2>/dev/null | awk -F: '{print $7}')" || current_shell="unknown"
  echo "Default shell: $current_shell"

  # Dependencies
  echo ""
  echo "Dependencies:"
  for cmd in git fzf fd eza curl; do
    if need_cmd "$cmd"; then
      echo "  $cmd: ✓"
    else
      echo "  $cmd: ✗"
    fi
  done

  echo "────────────────────────────────────────────────────────────────"
  echo ""
}

# ===== Print Usage Info =====
print_usage_info() {
  echo ""
  log_success "Zsh environment installed successfully!"
  echo ""
  log "First launch will install Zinit plugins automatically."
  log "Run 'p10k configure' to customize Powerlevel10k theme."
  echo ""
  log "To start using Zsh now:"
  echo "  zsh"
  echo ""
  log "Or log out and log back in for default shell."
  echo ""
  log "Useful aliases:"
  echo "  profile   - Open .zshrc in editor"
  echo "  rprofile  - Reload .zshrc"
  echo "  supdate   - System update (apt)"
  echo "  gupp      - Git push with message"
  echo ""
}

# ===== Main =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║           Zsh Environment Installer for Linux                ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  # Pre-flight checks
  require_cmd curl

  # Linux-only check
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [ "$OS" != "linux" ]; then
    die "This script is for Linux only. Detected OS: $OS"
  fi

  log "User: $ZSH_USER"
  log "Home: $ZSH_HOME"
  echo ""

  # Check if home exists
  if [ ! -d "$ZSH_HOME" ]; then
    die "Home directory $ZSH_HOME does not exist"
  fi

  # Installation steps
  install_zsh
  install_dependencies
  install_fonts
  create_directories
  download_zshrc
  create_p10k_config
  setup_nvm
  set_default_shell
  precompile_zsh
  verify_installation
  print_usage_info
}

# Run main
main "$@"
