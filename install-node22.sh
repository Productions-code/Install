#!/usr/bin/env sh
set -eu

# Install Node.js 22.x (LTS) for Linux from official Node.js binaries.
# Default: latest-v22.x (otomatis ikut update security/patch 22.x).

# ===== Config =====
PREFIX="${PREFIX:-/usr/local}"
INSTALL_ROOT="${INSTALL_ROOT:-$PREFIX/lib/nodejs}"   # tempat ekstrak
NODE_MAJOR="${1:-22}"                                # default 22
NODE_VERSION="${2:-}"                                # optional: "22.21.1" (tanpa 'v')
CHANNEL="${CHANNEL:-latest-v${NODE_MAJOR}.x}"         # default latest-v22.x

# ===== Helpers =====
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Error: butuh command '$1'"; exit 1; }; }

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
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "armv7l" ;;
    ppc64le) echo "ppc64le" ;;
    s390x) echo "s390x" ;;
    riscv64) echo "riscv64" ;;
    *) echo "Error: arsitektur tidak didukung: $a" >&2; exit 1 ;;
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

# ===== Checks =====
need_cmd curl
need_cmd tar
need_cmd sha256sum
need_cmd awk
need_cmd grep
ARCH="$(detect_arch)"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
if [ "$OS" != "linux" ]; then
  echo "Error: script ini khusus Linux. OS terdeteksi: $OS"
  exit 1
fi

# ===== Temp dir =====
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT INT TERM

BASE_URL=""
FILENAME=""

if [ -n "$NODE_VERSION" ]; then
  # explicit version, ex: 22.21.1 -> v22.21.1
  BASE_URL="https://nodejs.org/download/release/v${NODE_VERSION}"
  FILENAME="node-v${NODE_VERSION}-linux-${ARCH}.tar.xz"
else
  # channel latest-v22.x (otomatis terbaru 22.x)
  BASE_URL="https://nodejs.org/download/release/${CHANNEL}"
fi

echo "==> Base URL: $BASE_URL"

# ===== Download SHASUMS =====
echo "==> Download SHASUMS256.txt"
curl -fL "$BASE_URL/SHASUMS256.txt" -o "$TMPDIR/SHASUMS256.txt"

if [ -z "$FILENAME" ]; then
  # ambil nama file tar.xz yang cocok dari SHASUMS
  FILENAME="$(grep " node-v.*-linux-${ARCH}\.tar\.xz$" "$TMPDIR/SHASUMS256.txt" | awk '{print $2}' | head -n1 || true)"
  if [ -z "$FILENAME" ]; then
    echo "Error: tidak menemukan tarball untuk linux-$ARCH di SHASUMS256.txt"
    echo "Cek manual: $BASE_URL/"
    exit 1
  fi
fi

echo "==> Tarball: $FILENAME"

# ===== Download tarball =====
echo "==> Download tarball"
curl -fL "$BASE_URL/$FILENAME" -o "$TMPDIR/$FILENAME"

# ===== Verify SHA256 =====
echo "==> Verifikasi SHA256 (SHASUMS256.txt)"
grep " $FILENAME$" "$TMPDIR/SHASUMS256.txt" > "$TMPDIR/SHASUMS256.one"
( cd "$TMPDIR" && sha256sum -c SHASUMS256.one )

# ===== Install =====
as_root "mkdir -p '$INSTALL_ROOT'"

# tarball berisi folder seperti: node-v22.xx.x-linux-x64
NODE_FOLDER="$(echo "$FILENAME" | sed 's/\.tar\.xz$//')"

echo "==> Extract ke $INSTALL_ROOT"
as_root "rm -rf '$INSTALL_ROOT/$NODE_FOLDER'"
as_root "tar -C '$INSTALL_ROOT' -xJf '$TMPDIR/$FILENAME'"

# symlink supaya gampang dan konsisten
echo "==> Symlink: $PREFIX/node -> $INSTALL_ROOT/$NODE_FOLDER"
as_root "ln -sfn '$INSTALL_ROOT/$NODE_FOLDER' '$PREFIX/node'"

# optional: symlink binary ke /usr/local/bin (biasanya sudah di PATH)
echo "==> Symlink bin ke $PREFIX/bin"
as_root "mkdir -p '$PREFIX/bin'"
for b in node npm npx corepack; do
  if [ -f "$PREFIX/node/bin/$b" ]; then
    as_root "ln -sfn '$PREFIX/node/bin/$b' '$PREFIX/bin/$b'"
  fi
done

# ===== PATH setup (zsh dulu, fallback profile) =====
EXPORT_LINE='export PATH="$PATH:/usr/local/bin:/usr/local/node/bin"'

if [ "${SHELL:-}" = "/usr/bin/zsh" ] || [ "${SHELL:-}" = "/bin/zsh" ] || command -v zsh >/dev/null 2>&1; then
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
"$PREFIX/bin/corepack" enable >/dev/null 2>&1 || true

echo "==> Verifikasi:"
"$PREFIX/bin/node" -v
"$PREFIX/bin/npm" -v
echo "Selesai."
