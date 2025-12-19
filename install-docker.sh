#!/usr/bin/env sh
set -eu

# ============================================================================
# install-docker.sh - Advanced Docker Engine Installer for Linux
# ============================================================================
# Installs Docker Engine from official Docker repository with best practices.
#
# Features:
#   - Multi-distro support (Ubuntu, Debian, CentOS, Rocky, Fedora, Arch, Alpine)
#   - Official Docker GPG key and repository
#   - Installs Docker CE, Docker CLI, containerd, Buildx, Compose
#   - Add user to docker group (run without sudo)
#   - Enable and start Docker service
#   - Verify installation with hello-world
#   - Colored output with verbose mode
#
# Components Installed:
#   - docker-ce (Docker Engine)
#   - docker-ce-cli (Docker CLI)
#   - containerd.io (Container runtime)
#   - docker-buildx-plugin (Build tool)
#   - docker-compose-plugin (Compose v2)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-docker.sh)
#   DOCKER_USER=myuser ./install-docker.sh
#   SKIP_COMPOSE=1 ./install-docker.sh
#   VERBOSE=1 ./install-docker.sh
#
# Environment Variables:
#   DOCKER_USER   - User to add to docker group (default: current user)
#   SKIP_COMPOSE  - Skip installing docker-compose (default: 0)
#   SKIP_GROUP    - Skip adding user to docker group (default: 0)
#   SKIP_TEST     - Skip running hello-world test (default: 0)
#   VERBOSE       - Enable verbose output (default: 0)
# ============================================================================

# ===== Config =====
DOCKER_USER="${DOCKER_USER:-${SUDO_USER:-${USER:-}}}"
SKIP_COMPOSE="${SKIP_COMPOSE:-0}"
SKIP_GROUP="${SKIP_GROUP:-0}"
SKIP_TEST="${SKIP_TEST:-0}"
VERBOSE="${VERBOSE:-0}"

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

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu) echo "ubuntu" ;;
      debian|linuxmint|pop) echo "debian" ;;
      centos|rhel|rocky|almalinux|ol) echo "centos" ;;
      fedora) echo "fedora" ;;
      arch|manjaro) echo "arch" ;;
      alpine) echo "alpine" ;;
      opensuse*|sles) echo "suse" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

get_arch() {
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "armhf" ;;
    *) echo "$arch" ;;
  esac
}

# ===== Remove old Docker installations =====
remove_old_docker() {
  log_step "Removing old Docker installations (if any)"

  DISTRO="$(detect_distro)"

  case "$DISTRO" in
    ubuntu|debian)
      # Remove unofficial packages
      for pkg in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
        as_root "apt-get remove -y $pkg 2>/dev/null" || true
      done
      ;;
    centos|fedora)
      for pkg in docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc; do
        as_root "dnf remove -y $pkg 2>/dev/null" || as_root "yum remove -y $pkg 2>/dev/null" || true
      done
      ;;
    *)
      log_debug "Skipping removal for $DISTRO"
      ;;
  esac

  log_success "Old Docker packages removed"
}

# ===== Install on Ubuntu =====
install_ubuntu() {
  log_step "Installing Docker on Ubuntu"

  # Install prerequisites
  as_root "apt-get update -y"
  as_root "apt-get install -y ca-certificates curl"

  # Setup keyring directory
  as_root "install -m 0755 -d /etc/apt/keyrings"

  # Download Docker GPG key
  log "Adding Docker GPG key..."
  as_root "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
  as_root "chmod a+r /etc/apt/keyrings/docker.asc"

  # Get Ubuntu codename
  . /etc/os-release
  CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  log_debug "Ubuntu codename: $CODENAME"

  # Add repository (deb822 format)
  log "Adding Docker repository..."
  as_root "tee /etc/apt/sources.list.d/docker.sources" > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  # Install Docker packages
  as_root "apt-get update -y"

  if [ "$SKIP_COMPOSE" = "1" ]; then
    as_root "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
  else
    as_root "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  fi

  log_success "Docker installed on Ubuntu"
}

# ===== Install on Debian =====
install_debian() {
  log_step "Installing Docker on Debian"

  # Install prerequisites
  as_root "apt-get update -y"
  as_root "apt-get install -y ca-certificates curl"

  # Setup keyring directory
  as_root "install -m 0755 -d /etc/apt/keyrings"

  # Download Docker GPG key
  log "Adding Docker GPG key..."
  as_root "curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc"
  as_root "chmod a+r /etc/apt/keyrings/docker.asc"

  # Get Debian codename
  . /etc/os-release
  CODENAME="$VERSION_CODENAME"
  log_debug "Debian codename: $CODENAME"

  # Add repository (deb822 format)
  log "Adding Docker repository..."
  as_root "tee /etc/apt/sources.list.d/docker.sources" > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  # Install Docker packages
  as_root "apt-get update -y"

  if [ "$SKIP_COMPOSE" = "1" ]; then
    as_root "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
  else
    as_root "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  fi

  log_success "Docker installed on Debian"
}

# ===== Install on CentOS/Rocky/AlmaLinux =====
install_centos() {
  log_step "Installing Docker on CentOS/Rocky/AlmaLinux"

  # Install prerequisites
  if need_cmd dnf; then
    as_root "dnf -y install dnf-plugins-core"
    as_root "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"

    if [ "$SKIP_COMPOSE" = "1" ]; then
      as_root "dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
    else
      as_root "dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    fi
  else
    as_root "yum install -y yum-utils"
    as_root "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"

    if [ "$SKIP_COMPOSE" = "1" ]; then
      as_root "yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
    else
      as_root "yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    fi
  fi

  log_success "Docker installed on CentOS/Rocky"
}

# ===== Install on Fedora =====
install_fedora() {
  log_step "Installing Docker on Fedora"

  as_root "dnf -y install dnf-plugins-core"
  as_root "dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"

  if [ "$SKIP_COMPOSE" = "1" ]; then
    as_root "dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
  else
    as_root "dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  fi

  log_success "Docker installed on Fedora"
}

# ===== Install on Arch Linux =====
install_arch() {
  log_step "Installing Docker on Arch Linux"

  as_root "pacman -Sy --noconfirm docker docker-compose docker-buildx"

  log_success "Docker installed on Arch"
}

# ===== Install on Alpine =====
install_alpine() {
  log_step "Installing Docker on Alpine Linux"

  as_root "apk add --no-cache docker docker-cli docker-compose"

  log_success "Docker installed on Alpine"
}

# ===== Enable and Start Docker =====
start_docker_service() {
  log_step "Enabling and starting Docker service"

  DISTRO="$(detect_distro)"

  case "$DISTRO" in
    alpine)
      as_root "rc-update add docker default" || true
      as_root "service docker start" || as_root "rc-service docker start" || true
      ;;
    *)
      as_root "systemctl enable docker"
      as_root "systemctl start docker"
      ;;
  esac

  # Wait for Docker to be ready
  log "Waiting for Docker to start..."
  sleep 3

  if as_root "docker info" > /dev/null 2>&1; then
    log_success "Docker service is running"
  else
    log_warn "Docker may not be running properly"
  fi
}

# ===== Add User to Docker Group =====
add_user_to_docker_group() {
  [ "$SKIP_GROUP" = "1" ] && { log "Skipping docker group setup"; return 0; }

  if [ -z "$DOCKER_USER" ]; then
    log_warn "No user specified, skipping docker group"
    return 0
  fi

  log_step "Adding '$DOCKER_USER' to docker group"

  # Check if docker group exists
  if ! getent group docker > /dev/null 2>&1; then
    as_root "groupadd docker"
  fi

  # Add user to group
  as_root "usermod -aG docker '$DOCKER_USER'"

  log_success "User '$DOCKER_USER' added to docker group"
  log_warn "Log out and back in for group changes to take effect"
}

# ===== Test Installation =====
test_docker() {
  [ "$SKIP_TEST" = "1" ] && { log "Skipping Docker test"; return 0; }

  log_step "Testing Docker installation"

  if as_root "docker run --rm hello-world" > /dev/null 2>&1; then
    log_success "Docker is working correctly!"
  else
    log_warn "Docker test failed. Try running: sudo docker run hello-world"
  fi
}

# ===== Verify Installation =====
verify_installation() {
  log_step "Verifying installation"

  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "Docker Installation Summary"
  echo "────────────────────────────────────────────────────────────────"

  # Docker version
  if as_root "docker --version" > /dev/null 2>&1; then
    echo "Docker:    $(as_root 'docker --version' 2>/dev/null | head -n1)"
  else
    echo "Docker:    NOT INSTALLED"
  fi

  # Docker Compose version
  if as_root "docker compose version" > /dev/null 2>&1; then
    echo "Compose:   $(as_root 'docker compose version' 2>/dev/null | head -n1)"
  else
    echo "Compose:   NOT INSTALLED"
  fi

  # containerd
  if need_cmd containerd; then
    echo "containerd: $(containerd --version 2>/dev/null | head -n1)"
  fi

  # Docker status
  DISTRO="$(detect_distro)"
  if [ "$DISTRO" = "alpine" ]; then
    STATUS="$(as_root 'rc-service docker status 2>/dev/null' || echo 'unknown')"
  else
    STATUS="$(as_root 'systemctl is-active docker 2>/dev/null' || echo 'unknown')"
  fi
  echo "Status:    $STATUS"

  echo "────────────────────────────────────────────────────────────────"
  echo ""
}

# ===== Print Usage =====
print_usage() {
  echo ""
  log_success "Docker installed successfully!"
  echo ""
  log "Quick commands:"
  echo "  docker --version          # Check Docker version"
  echo "  docker compose version    # Check Compose version"
  echo "  docker run hello-world    # Test Docker"
  echo "  docker ps                 # List running containers"
  echo ""
  log "To run without sudo (after re-login):"
  echo "  docker ps"
  echo ""
  log "Docker flow:"
  echo "  Dockerfile → docker build → Image → docker run → Container"
  echo ""
}

# ===== Main =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              Docker Engine Installer for Linux               ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  # Pre-flight checks
  require_cmd curl

  # Linux-only check
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [ "$OS" != "linux" ]; then
    die "This script is for Linux only. Detected OS: $OS"
  fi

  # Check kernel version
  KERNEL="$(uname -r)"
  log "Kernel: $KERNEL"
  log "Architecture: $(get_arch)"

  # Detect distribution
  DISTRO="$(detect_distro)"
  if [ "$DISTRO" = "unknown" ]; then
    die "Unsupported Linux distribution"
  fi
  log "Distribution: $DISTRO"
  [ -n "$DOCKER_USER" ] && log "Docker user: $DOCKER_USER"
  echo ""

  # Remove old Docker
  remove_old_docker

  # Install based on distribution
  case "$DISTRO" in
    ubuntu)  install_ubuntu ;;
    debian)  install_debian ;;
    centos)  install_centos ;;
    fedora)  install_fedora ;;
    arch)    install_arch ;;
    alpine)  install_alpine ;;
    *)       die "Unsupported distribution: $DISTRO" ;;
  esac

  # Start Docker service
  start_docker_service

  # Add user to docker group
  add_user_to_docker_group

  # Test installation
  test_docker

  # Verify
  verify_installation

  # Print usage
  print_usage
}

# Run main
main "$@"
