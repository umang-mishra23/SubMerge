#!/bin/bash
set -euo pipefail   # <-- stops silent failures

# =========================
# SubMerge - Real Recon Tool
# Author: Umang Mishra
# Version: 1.1
# Legal: Authorized testing only
# =========================

print_banner() {
cat << "EOF"

   ███████╗██╗   ██╗██████╗ ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
   ██╔════╝██║   ██║██╔══██╗████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
   ███████╗██║   ██║██████╔╝██║████╔██║█████╗  ██████╔╝██║  ███╗█████╗  
   ╚════██║██║   ██║██╔══██╗██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝  
   ███████║╚██████╔╝██████╔╝██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
   ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        SubMerge - Unified Recon Framework (All subdomain tools)
                    Version 1.1
                    Author: Umang Mishra

   [!] Legal: Use only on targets you own or have permission to test!
EOF
}

if [ -z "${1:-}" ]; then
  print_banner
  echo "Usage: ./submerge.sh example.com"
  exit 1
fi

print_banner

DOMAIN="$1"
BASE="output/$DOMAIN"
RAW="$BASE/raw"
FINAL="$BASE/final"

# ---- CREATE DIRECTORIES (no sudo needed) ----
mkdir -p "$RAW" "$FINAL"
chmod -R 755 "output"

echo "[+] Target: $DOMAIN"
echo "[+] Output: $BASE"

# =========================
# 1) SUBDOMAIN ENUMERATION
# =========================

echo "[+] Running amass..."
amass enum -passive -d "$DOMAIN" -o "$RAW/amass.txt"

echo "[+] Running subfinder..."
subfinder -d "$DOMAIN" -silent -o "$RAW/subfinder.txt"

echo "[+] Running assetfinder..."
assetfinder --subs-only "$DOMAIN" > "$RAW/assetfinder.txt"

# Merge initial results
cat "$RAW"/amass.txt "$RAW"/subfinder.txt "$RAW"/assetfinder.txt \
  | sort -u > "$RAW/all_initial.txt"

COUNT_INIT=$(wc -l < "$RAW/all_initial.txt")
echo "[✔] Initial unique subdomains: $COUNT_INIT"

# =========================
# 2) DNSGEN (LIMITED!)
# =========================

echo "[+] Running dnsgen (SAFE MODE)..."

# LIMIT permutations to avoid explosion
dnsgen "$RAW/all_initial.txt" \
  | sort -u \
  | head -n 200000 \
  > "$RAW/dnsgen.txt"

# Merge originals + limited permutations
cat "$RAW/all_initial.txt" "$RAW/dnsgen.txt" \
  | sort -u > "$RAW/all_with_perms.txt"

COUNT_PERM=$(wc -l < "$RAW/all_with_perms.txt")
echo "[✔] After dnsgen (limited): $COUNT_PERM"

# =========================
# 3) MASSDNS (CHUNKED)
# =========================

echo "[+] Running massdns (chunked)..."

if [ ! -s "$RAW/all_with_perms.txt" ]; then
  echo "[!] ERROR: No domains to resolve. Exiting."
  exit 1
fi

> "$RAW/massdns.txt"

# Split into safe chunks
split -l 500000 "$RAW/all_with_perms.txt" "$RAW/chunk_"

for chunk in "$RAW"/chunk_*; do
  massdns -r resolvers.txt -t A -o S "$chunk" >> "$RAW/massdns.txt"
done

rm "$RAW"/chunk_*

# =========================
# 4) EXTRACT VALID A RECORDS
# =========================

grep " A " "$RAW/massdns.txt" \
 | awk '{print $1}' \
 | sed 's/\.$//' \
 | sort -u > "$FINAL/resolved.txt"

COUNT_RES=$(wc -l < "$FINAL/resolved.txt")
echo "[✔] Resolved subdomains: $COUNT_RES"

# =========================
# 5) ALIVE CHECK
# =========================

echo "[+] Running httprobe..."
cat "$FINAL/resolved.txt" | httprobe > "$FINAL/alive.txt"

COUNT_ALIVE=$(wc -l < "$FINAL/alive.txt")

echo "======================================"
echo "[✔] Total Resolved: $COUNT_RES"
echo "[✔] Alive Hosts:    $COUNT_ALIVE"
echo "[✔] Resolved File:  $FINAL/resolved.txt"
echo "[✔] Alive File:     $FINAL/alive.txt"
echo "======================================"
