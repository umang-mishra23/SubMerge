#!/bin/bash

# =========================
# SubMerge - Real Recon Tool
# Author: Umang Mishra
# Version: 1.0
# Legal: Authorized testing only
# =========================


print_banner() {
cat << "EOF"

   ███████╗██╗   ██╗██████╗ ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
   ██╔════╝██║   ██║██╔══██╗████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
   ███████╗██║   ██║██████╔╝██╔████╔██║█████╗  ██████╔╝██║  ███╗█████╗  
   ╚════██║██║   ██║██╔══██╗██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝  
   ███████║╚██████╔╝██████╔╝██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
   ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

              SubMerge - Unified Recon Framework (Include all subdomain finder tool)
                     Version 1.1
                     Author: Umang

   [!] Legal: Use only on targets you own or have permission to test!

EOF
}

if [ -z "$1" ]; then
  echo "Usage: ./submerge.sh example.com"
  exit 1
fi

DOMAIN=$1
BASE="output/$DOMAIN"
RAW="$BASE/raw"
FINAL="$BASE/final"

mkdir -p $RAW
mkdir -p $FINAL

echo "[+] Target: $DOMAIN"


# Subdomain Enumeration


echo "[+] Running amass..."
amass enum -passive -d $DOMAIN -o $RAW/amass.txt

echo "[+] Running subfinder..."
subfinder -d $DOMAIN -silent -o $RAW/subfinder.txt

echo "[+] Running assetfinder..."
assetfinder --subs-only $DOMAIN > $RAW/assetfinder.txt


# Merge initial subs


cat $RAW/*.txt | sort -u > $RAW/all_initial.txt


# Permutation with dnsgen


echo "[+] Running dnsgen..."
dnsgen $RAW/all_initial.txt > $RAW/dnsgen.txt


# Merge with permutations


cat $RAW/all_initial.txt $RAW/dnsgen.txt | sort -u > $RAW/all_with_perms.txt

# Resolve with massdns

echo "[+] Running massdns..."
massdns -r resolvers.txt -t A -o S \
  $RAW/all_with_perms.txt > $RAW/massdns.txt


# Extract valid domains

cat $RAW/massdns.txt | \
  awk '{print $1}' | \
  sed 's/\.$//' | \
  sort -u > $FINAL/resolved.txt

# Alive check with httprobe

echo "[+] Running httprobe..."
cat $FINAL/resolved.txt | httprobe > $FINAL/alive.txt

COUNT_ALL=$(wc -l < $FINAL/resolved.txt)
COUNT_ALIVE=$(wc -l < $FINAL/alive.txt)

echo "======================================"
echo "[✔] Total Resolved Subdomains: $COUNT_ALL"
echo "[✔] Total Alive Hosts: $COUNT_ALIVE"
echo "[✔] Resolved File: $FINAL/resolved.txt"
echo "[✔] Alive File:    $FINAL/alive.txt"
echo "======================================"
