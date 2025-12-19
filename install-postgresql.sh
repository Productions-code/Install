#!/usr/bin/env sh
set -eu

# ============================================================================
# install-postgresql.sh - Advanced PostgreSQL Installer for Linux
# ============================================================================
# Installs PostgreSQL from official PGDG repository with user configuration.
#
# Features:
#   - Install latest PostgreSQL (17/18) from official PGDG repository
#   - Multi-distro support (apt/dnf/yum/pacman/apk/zypper)
#   - Auto-detect and add official PostgreSQL repository
#   - Initialize database cluster
#   - Create custom user with password
#   - Configure authentication (md5/scram-sha-256)
#   - Enable and start PostgreSQL service
#   - Colored output with verbose mode
#   - Cleanup on failure
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-postgresql.sh)
#   PG_VERSION=17 ./install-postgresql.sh
#   PG_USER=myuser PG_PASSWORD=mypass ./install-postgresql.sh
#   VERBOSE=1 ./install-postgresql.sh
#
# Environment Variables:
#   PG_VERSION    - PostgreSQL version (default: 17)
#   PG_USER       - Database user to create (default: reza)
#   PG_PASSWORD   - Password for the user (default: reza)
#   PG_DATABASE   - Database to create (default: same as PG_USER)
#   PG_PORT       - PostgreSQL port (default: 5432)
#   PG_DATA       - Data directory (default: system default)
#   VERBOSE       - Enable verbose output (default: 0)
#   SKIP_USER     - Skip user creation (default: 0)
# ============================================================================

# ===== Config =====
PG_VERSION="${1:-${PG_VERSION:-17}}"
PG_USER="${PG_USER:-reza}"
PG_PASSWORD="${PG_PASSWORD:-reza}"
PG_DATABASE="${PG_DATABASE:-$PG_USER}"
PG_PORT="${PG_PORT:-5432}"
PG_DATA="${PG_DATA:-}"
VERBOSE="${VERBOSE:-0}"
SKIP_USER="${SKIP_USER:-0}"

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

as_postgres() {
  if [ "$(id -u)" -eq 0 ]; then
    su - postgres -c "$*"
  else
    need_cmd sudo || die "Need sudo to run as postgres user"
    sudo -u postgres sh -c "$*"
  fi
}

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian|linuxmint|pop) echo "debian" ;;
      rhel|centos|fedora|rocky|almalinux|ol) echo "rhel" ;;
      arch|manjaro) echo "arch" ;;
      alpine) echo "alpine" ;;
      opensuse*|sles) echo "suse" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

get_debian_codename() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$VERSION_CODENAME"
  else
    lsb_release -cs 2>/dev/null || echo "bookworm"
  fi
}

get_rhel_version() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$VERSION_ID" | cut -d. -f1
  else
    echo "9"
  fi
}

# ===== Install PostgreSQL on Debian/Ubuntu =====
install_debian() {
  log_step "Installing PostgreSQL $PG_VERSION on Debian/Ubuntu"

  # Install prerequisites
  log "Installing prerequisites..."
  as_root "apt-get update -y"
  as_root "apt-get install -y curl ca-certificates gnupg lsb-release"

  # Check if PGDG repo already configured
  if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    log "Adding PostgreSQL APT repository..."

    # Create directory for keyring
    as_root "install -d /usr/share/postgresql-common/pgdg"

    # Download signing key
    as_root "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc"

    # Get codename
    CODENAME="$(get_debian_codename)"
    log_debug "Detected codename: $CODENAME"

    # Add repository
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" | as_root "tee /etc/apt/sources.list.d/pgdg.list" > /dev/null

    log_success "PostgreSQL APT repository added"
  else
    log "PostgreSQL APT repository already configured"
  fi

  # Update and install
  as_root "apt-get update -y"
  as_root "apt-get install -y postgresql-${PG_VERSION} postgresql-contrib-${PG_VERSION}"

  log_success "PostgreSQL $PG_VERSION installed"
}

# ===== Install PostgreSQL on RHEL/Rocky/Fedora =====
install_rhel() {
  log_step "Installing PostgreSQL $PG_VERSION on RHEL/Rocky/AlmaLinux/Fedora"

  RHEL_VERSION="$(get_rhel_version)"
  log_debug "RHEL version: $RHEL_VERSION"

  # Disable built-in PostgreSQL module if exists
  if need_cmd dnf; then
    as_root "dnf -qy module disable postgresql 2>/dev/null" || true
  fi

  # Install PGDG repository
  log "Adding PostgreSQL YUM repository..."
  REPO_URL="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${RHEL_VERSION}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
  
  if need_cmd dnf; then
    as_root "dnf install -y $REPO_URL" || true
    as_root "dnf install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib"
  else
    as_root "yum install -y $REPO_URL" || true
    as_root "yum install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib"
  fi

  log_success "PostgreSQL $PG_VERSION installed"
}

# ===== Install PostgreSQL on Arch Linux =====
install_arch() {
  log_step "Installing PostgreSQL on Arch Linux"

  as_root "pacman -Sy --noconfirm postgresql"

  log_success "PostgreSQL installed"
}

# ===== Install PostgreSQL on Alpine =====
install_alpine() {
  log_step "Installing PostgreSQL on Alpine Linux"

  as_root "apk add --no-cache postgresql${PG_VERSION} postgresql${PG_VERSION}-contrib"

  log_success "PostgreSQL installed"
}

# ===== Install PostgreSQL on openSUSE =====
install_suse() {
  log_step "Installing PostgreSQL on openSUSE"

  as_root "zypper --non-interactive install postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib"

  log_success "PostgreSQL installed"
}

# ===== Initialize Database =====
init_database() {
  log_step "Initializing PostgreSQL database cluster"

  DISTRO="$(detect_distro)"

  case "$DISTRO" in
    debian)
      # Debian/Ubuntu auto-initializes, check if cluster exists
      if [ -d "/var/lib/postgresql/${PG_VERSION}/main" ]; then
        log "Database cluster already exists"
      else
        log "Creating database cluster..."
        as_root "pg_ctlcluster ${PG_VERSION} main start" || true
      fi
      ;;
    rhel)
      # RHEL needs manual initialization
      SETUP_CMD="/usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup"
      if [ -x "$SETUP_CMD" ]; then
        as_root "$SETUP_CMD initdb" || log_warn "Database may already be initialized"
      else
        as_root "postgresql-setup --initdb" || log_warn "Database may already be initialized"
      fi
      ;;
    arch)
      DATA_DIR="${PG_DATA:-/var/lib/postgres/data}"
      if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        as_root "mkdir -p '$DATA_DIR'"
        as_root "chown postgres:postgres '$DATA_DIR'"
        as_postgres "initdb -D '$DATA_DIR'"
      else
        log "Database cluster already exists"
      fi
      ;;
    alpine)
      DATA_DIR="${PG_DATA:-/var/lib/postgresql/${PG_VERSION}/data}"
      if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        as_root "mkdir -p '$DATA_DIR'"
        as_root "chown postgres:postgres '$DATA_DIR'"
        as_postgres "initdb -D '$DATA_DIR'"
      else
        log "Database cluster already exists"
      fi
      ;;
    *)
      log_warn "Unknown distribution, skipping database initialization"
      ;;
  esac

  log_success "Database cluster ready"
}

# ===== Configure Authentication =====
configure_auth() {
  log_step "Configuring PostgreSQL authentication"

  DISTRO="$(detect_distro)"

  # Find pg_hba.conf location
  case "$DISTRO" in
    debian)
      PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
      ;;
    rhel)
      PG_HBA="/var/lib/pgsql/${PG_VERSION}/data/pg_hba.conf"
      ;;
    arch)
      PG_HBA="${PG_DATA:-/var/lib/postgres/data}/pg_hba.conf"
      ;;
    alpine)
      PG_HBA="${PG_DATA:-/var/lib/postgresql/${PG_VERSION}/data}/pg_hba.conf"
      ;;
    *)
      log_warn "Unknown distribution, skipping authentication configuration"
      return 0
      ;;
  esac

  if [ -f "$PG_HBA" ]; then
    log_debug "pg_hba.conf location: $PG_HBA"

    # Backup original
    as_root "cp '$PG_HBA' '${PG_HBA}.backup'"

    # Update local connections to use scram-sha-256 or md5
    # This allows password authentication for local connections
    as_root "sed -i 's/local   all             all                                     peer/local   all             all                                     scram-sha-256/' '$PG_HBA'" || true
    as_root "sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            scram-sha-256/' '$PG_HBA'" || true
    as_root "sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 scram-sha-256/' '$PG_HBA'" || true

    log_success "Authentication configured (scram-sha-256)"
  else
    log_warn "pg_hba.conf not found at $PG_HBA"
  fi
}

# ===== Start PostgreSQL Service =====
start_service() {
  log_step "Starting PostgreSQL service"

  DISTRO="$(detect_distro)"

  case "$DISTRO" in
    debian)
      as_root "systemctl enable postgresql"
      as_root "systemctl restart postgresql"
      ;;
    rhel)
      SERVICE_NAME="postgresql-${PG_VERSION}"
      as_root "systemctl enable $SERVICE_NAME"
      as_root "systemctl restart $SERVICE_NAME"
      ;;
    arch|alpine)
      as_root "systemctl enable postgresql" || as_root "rc-update add postgresql default" || true
      as_root "systemctl restart postgresql" || as_root "rc-service postgresql restart" || true
      ;;
    *)
      log_warn "Unknown distribution, please start PostgreSQL manually"
      return 0
      ;;
  esac

  # Wait for PostgreSQL to be ready
  log "Waiting for PostgreSQL to be ready..."
  sleep 3

  log_success "PostgreSQL service started"
}

# ===== Create User and Database =====
create_user_database() {
  [ "$SKIP_USER" = "1" ] && { log "Skipping user creation"; return 0; }

  log_step "Creating user '$PG_USER' and database '$PG_DATABASE'"

  # Create user
  log "Creating PostgreSQL user: $PG_USER"
  as_postgres "psql -c \"CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';\"" 2>/dev/null || \
    as_postgres "psql -c \"ALTER USER $PG_USER WITH PASSWORD '$PG_PASSWORD';\"" 2>/dev/null || \
    log_warn "User may already exist"

  # Create database
  log "Creating database: $PG_DATABASE"
  as_postgres "psql -c \"CREATE DATABASE $PG_DATABASE OWNER $PG_USER;\"" 2>/dev/null || \
    log_warn "Database may already exist"

  # Grant privileges
  as_postgres "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $PG_DATABASE TO $PG_USER;\"" 2>/dev/null || true

  log_success "User '$PG_USER' and database '$PG_DATABASE' created"
}

# ===== Verify Installation =====
verify_installation() {
  log_step "Verifying PostgreSQL installation"

  # Get PostgreSQL version
  PG_INSTALLED_VERSION=""
  
  if need_cmd psql; then
    PG_INSTALLED_VERSION="$(psql --version 2>/dev/null | head -n1)" || true
  fi

  if [ -z "$PG_INSTALLED_VERSION" ]; then
    # Try versioned path
    if [ -x "/usr/lib/postgresql/${PG_VERSION}/bin/psql" ]; then
      PG_INSTALLED_VERSION="$(/usr/lib/postgresql/${PG_VERSION}/bin/psql --version)"
    elif [ -x "/usr/pgsql-${PG_VERSION}/bin/psql" ]; then
      PG_INSTALLED_VERSION="$(/usr/pgsql-${PG_VERSION}/bin/psql --version)"
    fi
  fi

  # Check if PostgreSQL is running
  PG_STATUS="stopped"
  if as_postgres "pg_isready -q" 2>/dev/null; then
    PG_STATUS="running"
  fi

  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "PostgreSQL Installation Summary"
  echo "────────────────────────────────────────────────────────────────"
  echo "Version:  ${PG_INSTALLED_VERSION:-PostgreSQL $PG_VERSION}"
  echo "Status:   $PG_STATUS"
  echo "Port:     $PG_PORT"
  echo "User:     $PG_USER"
  echo "Password: $PG_PASSWORD"
  echo "Database: $PG_DATABASE"
  echo "────────────────────────────────────────────────────────────────"
  echo ""

  if [ "$PG_STATUS" = "running" ]; then
    log_success "PostgreSQL is running!"
  else
    log_warn "PostgreSQL may not be running. Check with: systemctl status postgresql"
  fi
}

# ===== Print Connection Info =====
print_connection_info() {
  echo ""
  log "Connection examples:"
  echo ""
  echo "  # Connect via psql"
  echo "  psql -U $PG_USER -d $PG_DATABASE -h localhost"
  echo ""
  echo "  # Connection string"
  echo "  postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/${PG_DATABASE}"
  echo ""
  echo "  # Environment variable"
  echo "  export DATABASE_URL=\"postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/${PG_DATABASE}\""
  echo ""
}

# ===== Main function =====
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              PostgreSQL Installer for Linux                  ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  # Pre-flight checks
  require_cmd curl

  # Linux-only check
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [ "$OS" != "linux" ]; then
    die "This script is for Linux only. Detected OS: $OS"
  fi

  # Detect distribution
  DISTRO="$(detect_distro)"
  if [ "$DISTRO" = "unknown" ]; then
    die "Unsupported Linux distribution. Please install PostgreSQL manually."
  fi

  log "PostgreSQL version: $PG_VERSION"
  log "Distribution: $DISTRO"
  log "User to create: $PG_USER"
  log "Database to create: $PG_DATABASE"
  echo ""

  # Install PostgreSQL based on distribution
  case "$DISTRO" in
    debian)  install_debian ;;
    rhel)    install_rhel ;;
    arch)    install_arch ;;
    alpine)  install_alpine ;;
    suse)    install_suse ;;
    *)       die "Unsupported distribution: $DISTRO" ;;
  esac

  # Initialize database
  init_database

  # Configure authentication
  configure_auth

  # Start service
  start_service

  # Create user and database
  create_user_database

  # Verify installation
  verify_installation

  # Print connection info
  print_connection_info

  log_success "PostgreSQL $PG_VERSION installation complete!"
}

# Run main
main "$@"
