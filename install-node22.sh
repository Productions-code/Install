#!/usr/bin/env sh
set -eu

# Install Node.js 22.x (LTS) for Linux from official Node.js binaries.
# Default: latest-v22.x (otomatis ikut update security/patch 22.x).
#
# Features:
# - Auto-detect arch
# - Download from official Node.js release dir
# - Verify SHA256 via SHASUMS256.txt
# - Auto-install xz if missing (apt/dnf/yum/pacman/apk/zypper)
# - Fallback to .tar.gz if xz can't be used
# - Install into /usr/local/lib/nodejs and symlink to /usr/local/node + /usr/local/bin
# - zsh/bash profile PATH append (idempotent)
# - Auto-upgrade npm to 11.7.0 (can be disabled)

# ===== Config =====
PREFIX="${PREFIX:-/usr/local}"
INSTALL_ROOT="${INSTALL_ROOT:-$PREFIX/lib/nodejs}"    # tempat ekstrak
NODE_MAJOR="${1:-22}"                                 # default 22
NODE_VERSION="${2:-}"                                 # optional: "22.21.1" (tanpa 'v')
CHANNEL="${CHANNEL:-latest-v${NODE_MAJOR}.x}"          # default latest-v22.x
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"            # 1 = auto install xz, 0 = tidak
FORCE_TARGZ="${FORCE_TARGZ:-0}"                        # 1 = paksa pakai tar.gz

# npm upgrade settings
NPM_VERSION="${NPM_VERSION:-11.7.0}"                   # paksa npm versi ini
AUTO_UPDATE_NPM="${AUTO_UPDATE_NPM:-1}"                # 1 = upgrade npm, 0 = skip

# ===== Helpers =====
need_cmd() { command -v "$1" >/dev/null 2>&1 || return 1; }
die() { echo "Error: $*" >&2; exit 1; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    sh -c "$*"
  else
    need_cmd sudo || die "butuh sudo (atau jalankan sebagai root)"
    sudo sh -c "$*"
  fi
}

detect_arch() {
  a="$(uname -m)"
  case "$a" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "armv7l" ;;
    ppc64le) echo "ppc64le" ;;
    s390x) echo "s390x" ;;
    riscv64) echo "riscv64" ;;
    *) die "arsitektur tidak didukung: $a" ;;
  esac
}

append_once() {
  file="$1"
  line="$2"
  touch "$file"
  if ! grep -Fqs "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
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

  [ "$AUTO_INSTALL_DEPS" = "1" ] || die "xz belum terpasang. Install dulu (contoh: apt install xz-utils) lalu ulangi."

  pm="$(detect_pkg_mgr)"
  [ -n "$pm" ] || die "xz belum terpasang dan package manager tidak terdeteksi. Install xz manual."

  echo "==> xz tidak ditemukan. Install dependency (xz) via $pm ..."
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
      die "package manager tidak didukung: $pm"
      ;;
  esac

  need_cmd xz || die "xz masih tidak tersedia setelah install. Cek repositori/paket."
}

maybe_update_npm() {
  [ "$AUTO_UPDATE_NPM" = "1" ] || return 0
  [ -n "${NPM_VERSION:-}" ] || return 0

  NPM_BIN="$PREFIX/bin/npm"
  NODE_BIN="$PREFIX/bin/node"

  [ -x "$NODE_BIN" ] || die "node tidak ditemukan di $NODE_BIN"
  [ -x "$NPM_BIN" ] || die "npm tidak ditemukan di $NPM_BIN"

  current="$("$NPM_BIN" -v 2>/dev/null || true)"
  if [ "$current" = "$NPM_VERSION" ]; then
    echo "==> npm sudah versi $NPM_VERSION"
    return 0
  fi

  echo "==> Update npm: ${current:-unknown} -> $NPM_VERSION"
  if [ "$(id -u)" -eq 0 ]; then
    "$NPM_BIN" install -g "npm@${NPM_VERSION}"
  else
    need_cmd sudo || die "butuh sudo untuk update npm global ke $NPM_VERSION"
    sudo "$NPM_BIN" install -g "npm@${NPM_VERSION}"
  fi

  echo "==> npm versi sekarang: $("$NPM_BIN" -v)"
}

# ===== Checks =====
need_cmd curl || die "butuh curl"
need_cmd tar || die "butuh tar"
need_cmd sha256sum || die "butuh sha256sum"
need_cmd awk || die "butuh awk"
need_cmd grep || die "butuh grep"
need_cmd sed || die "butuh sed"

ARCH="$(detect_arch)"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
[ "$OS" = "linux" ] || die "script ini khusus Linux. OS terdeteksi: $OS"

# ===== Temp dir =====
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT INT TERM

BASE_URL=""
FILENAME=""
EXT="tar.xz"

if [ "$FORCE_TARGZ" = "1" ]; then
  EXT="tar.gz"
fi

if [ -n "$NODE_VERSION" ]; then
  BASE_URL="https://nodejs.org/download/release/v${NODE_VERSION}"
else
  BASE_URL="https://nodejs.org/download/release/${CHANNEL}"
fi

echo "==> Base URL: $BASE_URL"

# ===== Download SHASUMS =====
echo "==> Download SHASUMS256.txt"
curl -fL "$BASE_URL/SHASUMS256.txt" -o "$TMPDIR/SHASUMS256.txt"

# ===== Decide tarball =====
pick_filename() {
  ext="$1"
  grep " node-v.*-linux-${ARCH}\.${ext}$" "$TMPDIR/SHASUMS256.txt" | awk '{print $2}' | head -n1 || true
}

if [ -n "$NODE_VERSION" ]; then
  FILENAME="node-v${NODE_VERSION}-linux-${ARCH}.${EXT}"
else
  FILENAME="$(pick_filename "$EXT")"
fi

# Jika tar.xz tidak ketemu, fallback tar.gz
if [ -z "$FILENAME" ] || ! grep -q " $FILENAME$" "$TMPDIR/SHASUMS256.txt"; then
  if [ "$EXT" = "tar.xz" ]; then
    echo "==> tar.xz tidak tersedia untuk linux-$ARCH, fallback ke tar.gz"
    EXT="tar.gz"
    if [ -n "$NODE_VERSION" ]; then
      FILENAME="node-v${NODE_VERSION}-linux-${ARCH}.tar.gz"
    else
      FILENAME="$(pick_filename "tar.gz")"
    fi
  fi
fi

[ -n "$FILENAME" ] || die "tidak menemukan tarball yang cocok untuk linux-$ARCH. Cek: $BASE_URL/"

echo "==> Tarball: $FILENAME"

# ===== Download tarball =====
echo "==> Download tarball"
curl -fL "$BASE_URL/$FILENAME" -o "$TMPDIR/$FILENAME"

# ===== Verify SHA256 =====
echo "==> Verifikasi SHA256 (SHASUMS256.txt)"
grep " $FILENAME$" "$TMPDIR/SHASUMS256.txt" > "$TMPDIR/SHASUMS256.one"
( cd "$TMPDIR" && sha256sum -c SHASUMS256.one )

# ===== Ensure extractor =====
if [ "$EXT" = "tar.xz" ]; then
  install_xz_if_missing
fi

# ===== Install =====
as_root "mkdir -p '$INSTALL_ROOT'"

NODE_FOLDER="$(echo "$FILENAME" | sed 's/\.tar\.xz$//; s/\.tar\.gz$//')"

echo "==> Extract ke $INSTALL_ROOT"
as_root "rm -rf '$INSTALL_ROOT/$NODE_FOLDER'"

if [ "$EXT" = "tar.xz" ]; then
  as_root "tar -C '$INSTALL_ROOT' -xJf '$TMPDIR/$FILENAME'"
else
  as_root "tar -C '$INSTALL_ROOT' -xzf '$TMPDIR/$FILENAME'"
fi

# symlink supaya gampang dan konsisten
echo "==> Symlink: $PREFIX/node -> $INSTALL_ROOT/$NODE_FOLDER"
as_root "ln -sfn '$INSTALL_ROOT/$NODE_FOLDER' '$PREFIX/node'"

# symlink binary ke /usr/local/bin
echo "==> Symlink bin ke $PREFIX/bin"
as_root "mkdir -p '$PREFIX/bin'"
for b in node npm npx corepack; do
  if [ -f "$PREFIX/node/bin/$b" ]; then
    as_root "ln -sfn '$PREFIX/node/bin/$b' '$PREFIX/bin/$b'"
  fi
done

# ===== PATH setup (zsh dulu, fallback profile) =====
# Karena bin disymlink ke /usr/local/bin, umumnya sudah ada di PATH.
# Tapi kita tetap tambahkan secara idempotent kalau belum.
EXPORT_LINE='export PATH="/usr/local/bin:$PATH"'

if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || need_cmd zsh; then
  echo "==> Tambah PATH ke ~/.zprofile dan ~/.zshrc"
  append_once "$HOME/.zprofile" "$EXPORT_LINE"
  append_once "$HOME/.zshrc" "$EXPORT_LINE"
  echo "==> Aktifkan sekarang: source ~/.zprofile"
else
  echo "==> Tambah PATH ke ~/.profile"
  append_once "$HOME/.profile" "$EXPORT_LINE"
  echo "==> Aktifkan sekarang: . ~/.profile"
fi

# enable corepack (optional)
if [ -x "$PREFIX/bin/corepack" ]; then
  "$PREFIX/bin/corepack" enable >/dev/null 2>&1 || true
fi

# upgrade npm to required version
maybe_update_npm

echo "==> Verifikasi:"
echo "node: $("$PREFIX/bin/node" -v)"
echo "npm : $("$PREFIX/bin/npm" -v)"
echo "path node: $(command -v node || true)"
echo "path npm : $(command -v npm || true)"
echo "Selesai."
