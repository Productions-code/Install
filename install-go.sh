#!/usr/bin/env sh
set -eu

# ===== Config (bisa override lewat argumen) =====
GO_VERSION="${1:-1.25.5}"   # contoh: ./install-go.sh 1.25.5
PREFIX="${PREFIX:-/usr/local}"
GO_DIR="$PREFIX/go"

# ===== Helpers =====
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Error: butuh command '$1'."; exit 1; }; }
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    sh -c "$*"
  else
    need_cmd sudo
    sudo sh -c "$*"
  fi
}

detect_arch() {
  a="$(uname -m)"
  case "$a" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    i386|i686) echo "386" ;;
    armv6l) echo "armv6l" ;;
    armv7l) echo "armv6l" ;; # Go tarball biasanya armv6l untuk 32-bit arm
    *) echo "Error: arsitektur tidak didukung: $a" >&2; exit 1 ;;
  esac
}

append_once() {
  file="$1"
  line="$2"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file"
  if ! grep -Fqs "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

# ===== Checks =====
need_cmd curl
need_cmd tar
ARCH="$(detect_arch)"

# Linux-only (sesuai kebutuhan kamu)
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
if [ "$OS" != "linux" ]; then
  echo "Error: script ini khusus Linux. OS terdeteksi: $OS"
  exit 1
fi

TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
URL="https://go.dev/dl/${TARBALL}"

echo "==> Download: $URL"
TMP="/tmp/${TARBALL}"
curl -fL "$URL" -o "$TMP"

echo "==> Hapus Go lama (kalau ada): $GO_DIR"
as_root "rm -rf '$GO_DIR'"

echo "==> Extract ke $PREFIX"
as_root "tar -C '$PREFIX' -xzf '$TMP'"

# ===== PATH setup (zsh dulu, fallback profile) =====
EXPORT_LINE='export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"'

if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || command -v zsh >/dev/null 2>&1; then
  ZPROFILE="$HOME/.zprofile"
  ZSHRC="$HOME/.zshrc"
  echo "==> Tambah PATH ke $ZPROFILE (dan $ZSHRC)"
  append_once "$ZPROFILE" "$EXPORT_LINE"
  append_once "$ZSHRC" "$EXPORT_LINE"
  echo "==> Aktifkan sekarang: source ~/.zprofile (atau buka terminal baru)"
else
  PROFILE="$HOME/.profile"
  echo "==> Tambah PATH ke $PROFILE"
  append_once "$PROFILE" "$EXPORT_LINE"
  echo "==> Aktifkan sekarang: . ~/.profile (atau login ulang)"
fi

echo "==> Verifikasi:"
/usr/local/go/bin/go version || true
echo "Selesai."
