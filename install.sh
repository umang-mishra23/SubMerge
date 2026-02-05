#!/bin/bash

echo "[+] Installing dependencies for SubMerge..."

# Update system
sudo apt update

# Install amass
echo "[+] Installing amass..."
sudo apt install -y amass

echo "[+] Updating amass DB..."
sudo amass db -update

# Install Go tools
echo "[+] Installing Go tools..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/tomnomnom/httprobe@latest

# Install dnsgen
echo "[+] Installing dnsgen..."
pip3 install dnsgen

# Install massdns
echo "[+] Installing massdns..."
git clone https://github.com/blechschmidt/massdns.git /tmp/massdns
cd /tmp/massdns
make
sudo cp bin/massdns /usr/local/bin/
cd -

# Add Go to PATH
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc

echo "[✔] All dependencies installed!"
