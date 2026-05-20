#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="${LOGFILE:-$SCRIPT_DIR/install.log}"
TMPDIR="${TMPDIR:-/tmp/submerge-install}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$TMPDIR"
: > "$LOGFILE"

info()  { printf "${YELLOW}[+] %s${NC}\n" "$*"; }
ok()    { printf "${GREEN}[✔] %s${NC}\n" "$*"; }
fail()  { printf "${RED}[✘] %s${NC}\n" "$*" >&2; exit 1; }

run_logged() {
  "$@" >>"$LOGFILE" 2>&1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

install_apt_pkg() {
  local pkg="$1"

  if dpkg -s "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
    return 0
  fi

  info "Installing $pkg..."
  if run_logged sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"; then
    ok "$pkg installed"
  else
    fail "Failed to install $pkg (see $LOGFILE)"
  fi
}

ensure_base_tools() {
  info "Updating package lists..."
  run_logged sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y || fail "apt update failed (see $LOGFILE)"

  install_apt_pkg curl
  install_apt_pkg unzip
  install_apt_pkg git
  install_apt_pkg build-essential
  install_apt_pkg pipx
  install_apt_pkg amass

  if ! have go; then
    install_apt_pkg golang-go
  fi
}

ensure_path() {
  local go_bin
  go_bin="$(go env GOPATH)/bin"

  export PATH="$PATH:$go_bin:$HOME/.local/bin"

  grep -qxF "export PATH=\$PATH:$go_bin:\$HOME/.local/bin" "$HOME/.bashrc" 2>/dev/null || \
    printf 'export PATH=$PATH:%s:$HOME/.local/bin\n' "$go_bin" >> "$HOME/.bashrc"
}

install_go_tool() {
  local name="$1"
  local pkg="$2"
  local bin="$3"

  if have "$bin"; then
    ok "$name already installed"
    return 0
  fi

  info "Installing $name..."
  if run_logged go install "$pkg@latest"; then
    ok "$name installed"
  else
    fail "Failed to install $name (see $LOGFILE)"
  fi
}

install_dnsgen() {
  if have dnsgen; then
    ok "dnsgen already installed"
    return 0
  fi

  info "Installing dnsgen..."
  if run_logged pipx install dnsgen; then
    ok "dnsgen installed"
  else
    fail "Failed to install dnsgen (see $LOGFILE)"
  fi
}

install_findomain() {
  if have findomain; then
    ok "findomain already installed"
    return 0
  fi

  info "Installing findomain (prebuilt binary)..."

  local arch url zipfile bindir
  arch="$(uname -m)"

  case "$arch" in
    x86_64|amd64)
      url="https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip"
      ;;
    aarch64|arm64)
      url="https://github.com/findomain/findomain/releases/latest/download/findomain-aarch64.zip"
      ;;
    armv7l|armv7*)
      url="https://github.com/findomain/findomain/releases/latest/download/findomain-armv7.zip"
      ;;
    *)
      fail "Unsupported architecture: $arch"
      ;;
  esac

  zipfile="$TMPDIR/findomain.zip"
  bindir="$TMPDIR/findomain-bin"
  rm -rf "$bindir"
  mkdir -p "$bindir"

  if ! run_logged curl -fsSL "$url" -o "$zipfile"; then
    fail "Failed to download findomain (see $LOGFILE)"
  fi

  if ! run_logged unzip -o -q "$zipfile" -d "$bindir"; then
    fail "Failed to unzip findomain (see $LOGFILE)"
  fi

  if [[ ! -f "$bindir/findomain" ]]; then
    fail "findomain binary not found after extraction"
  fi

  chmod +x "$bindir/findomain"
  if run_logged sudo install -m 0755 "$bindir/findomain" /usr/local/bin/findomain; then
    ok "findomain installed"
  else
    fail "Failed to place findomain in /usr/local/bin (see $LOGFILE)"
  fi
}

install_massdns() {
  if have massdns; then
    ok "massdns already installed"
    return 0
  fi

  info "Installing massdns..."
  rm -rf "$TMPDIR/massdns"
  if ! run_logged git clone --depth 1 https://github.com/blechschmidt/massdns.git "$TMPDIR/massdns"; then
    fail "Failed to clone massdns (see $LOGFILE)"
  fi

  if ! run_logged make -C "$TMPDIR/massdns"; then
    fail "Failed to build massdns (see $LOGFILE)"
  fi

  if run_logged sudo install -m 0755 "$TMPDIR/massdns/bin/massdns" /usr/local/bin/massdns; then
    ok "massdns installed"
  else
    fail "Failed to install massdns binary (see $LOGFILE)"
  fi
}

main() {
  echo "SubMerge installer"
  echo "Log file: $LOGFILE"
  echo

  ensure_base_tools
  ensure_path

  install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" "subfinder"
  install_go_tool "httpx" "github.com/projectdiscovery/httpx/cmd/httpx" "httpx"
  install_go_tool "assetfinder" "github.com/tomnomnom/assetfinder" "assetfinder"

  install_dnsgen
  install_findomain
  install_massdns

  echo
  ok "All dependencies installed"
  echo "[*] Reload your shell or run: source ~/.bashrc"
  echo "[*] Full install details are saved in: $LOGFILE"
}

main "$@"