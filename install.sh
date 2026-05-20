#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

echo "[+] Installing dependencies for SubMerge..."

# System update
sudo apt update

# Core packages
echo "[+] Installing core system packages..."
sudo apt install -y amass git build-essential rustc cargo pipx

# Go bin path for current shell and future shells
GO_BIN="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin"
export PATH="$PATH:$GO_BIN:$HOME/.local/bin"
grep -qxF "export PATH=\$PATH:$GO_BIN" ~/.bashrc 2>/dev/null || echo "export PATH=\$PATH:$GO_BIN" >> ~/.bashrc
grep -qxF 'export PATH=$PATH:$HOME/.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc

# Install Go tools
echo "[+] Installing Go tools..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/tomnomnom/assetfinder@latest

# Install dnsgen safely on Kali
echo "[+] Installing dnsgen..."
pipx install dnsgen

# Install findomain
echo "[+] Installing findomain..."
cargo install findomain

# Install massdns
echo "[+] Installing massdns..."
rm -rf /tmp/massdns
git clone https://github.com/blechschmidt/massdns.git /tmp/massdns
cd /tmp/massdns
make
sudo install -m 0755 bin/massdns /usr/local/bin/massdns
cd - >/dev/null

# No amass DB update needed for current Amass versions
# Old command removed:
# sudo amass db -update

echo "[✔] All dependencies installed!"
echo "[+] Restart your shell or run: source ~/.bashrc"