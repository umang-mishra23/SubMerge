#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

# =========================
# SubMerge - Refined Recon Tool
# Author: Umang Mishra
# Version: 1.3
# Legal: Use only on targets you own or have permission to test.
# =========================

SCRIPT_NAME="$(basename "$0")"

DOMAIN="${1:-}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
RESOLVERS_FILE="${RESOLVERS_FILE:-resolvers.txt}"
CHUNK_SIZE="${CHUNK_SIZE:-500000}"
DNSGEN_LIMIT="${DNSGEN_LIMIT:-200000}"
KEEP_TEMP="${KEEP_TEMP:-0}"

print_banner() {
cat <<'EOF'

   ███████╗██╗   ██╗██████╗ ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
   ██╔════╝██║   ██║██╔══██╗████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
   ███████╗██║   ██║██████╔╝██║████╔██║█████╗  ██████╔╝██║  ███╗█████╗
   ╚════██║██║   ██║██╔══██╗██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝
   ███████║╚██████╔╝██████╔╝██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
   ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        SubMerge - Unified Recon Framework
                  Version 1.3
                  Author: Umang Mishra

   [!] Legal: Use only on targets you own or have permission to test!
EOF
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME example.com

Environment variables:
  OUTPUT_ROOT=output
  RESOLVERS_FILE=resolvers.txt
  CHUNK_SIZE=500000
  DNSGEN_LIMIT=200000
  KEEP_TEMP=0
EOF
}

log()  { printf '[*] %s\n' "$*"; }
ok()   { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

require_cmds() {
  local missing=()
  local cmds=(amass subfinder assetfinder findomain dnsgen massdns httpx sort awk sed wc head split cat grep)

  for c in "${cmds[@]}"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done

  if ((${#missing[@]} > 0)); then
    die "Missing required tools: ${missing[*]}"
  fi
}

validate_domain() {
  [[ -n "$DOMAIN" ]] || { usage; exit 1; }
  [[ "$DOMAIN" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || die "Invalid domain: $DOMAIN"
}

cleanup() {
  if [[ "$KEEP_TEMP" -eq 0 && -n "${RAW:-}" ]]; then
    rm -f "$RAW"/chunk_* 2>/dev/null || true
  fi
}

trap cleanup EXIT

main() {
  print_banner
  validate_domain
  require_cmds

  BASE="$OUTPUT_ROOT/$DOMAIN"
  RAW="$BASE/raw"
  FINAL="$BASE/final"

  mkdir -p "$RAW" "$FINAL"
  chmod -R 755 "$OUTPUT_ROOT" || true

  log "Target: $DOMAIN"
  log "Output: $BASE"

  : > "$RAW/amass.txt"
  : > "$RAW/subfinder.txt"
  : > "$RAW/assetfinder.txt"
  : > "$RAW/findomain.txt"
  : > "$RAW/massdns.txt"
  : > "$FINAL/resolved.txt"
  : > "$FINAL/alive.txt"

  pids=()

  log "amass..."
  { amass enum -passive -d "$DOMAIN" > "$RAW/amass.txt"; } &
  pids+=($!)

  log "subfinder..."
  subfinder -d "$DOMAIN" -silent -o "$RAW/subfinder.txt" &
  pids+=($!)

  log "assetfinder..."
  { assetfinder --subs-only "$DOMAIN" > "$RAW/assetfinder.txt"; } &
  pids+=($!)

  log "findomain..."
  { findomain -t "$DOMAIN" -q > "$RAW/findomain.txt"; } &
  pids+=($!)

  failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
      warn "One enumeration job failed"
    fi
  done

  if [[ "$failed" -eq 1 ]]; then
    warn "Continuing with whatever output was collected"
  fi

  cat "$RAW"/amass.txt \
      "$RAW"/subfinder.txt \
      "$RAW"/assetfinder.txt \
      "$RAW"/findomain.txt 2>/dev/null \
    | sed 's/\r$//' \
    | awk 'NF' \
    | sort -u > "$RAW/all_initial.txt"

  COUNT_INIT="$(wc -l < "$RAW/all_initial.txt" | tr -d ' ')"
  ok "Initial unique subdomains: $COUNT_INIT"

  if [[ -s "$RAW/all_initial.txt" ]]; then
    log "Running dnsgen (limited)..."
    dnsgen "$RAW/all_initial.txt" \
    | sed 's/\r$//' \
    | awk 'NF' \
    | sort -u \
    | awk -v limit="$DNSGEN_LIMIT" 'NR<=limit' > "$RAW/dnsgen.txt"

  if [[ ! -s "$RAW/dnsgen.txt" ]]; then
    warn "dnsgen produced no output"
  fi

    cat "$RAW/all_initial.txt" "$RAW/dnsgen.txt" \
      | sed 's/\r$//' \
      | awk 'NF' \
      | sort -u > "$RAW/all_with_perms.txt"
  else
    : > "$RAW/all_with_perms.txt"
    warn "No initial subdomains found; skipping dnsgen"
  fi

  COUNT_PERM="$(wc -l < "$RAW/all_with_perms.txt" | tr -d ' ')"
  ok "After dnsgen (limited): $COUNT_PERM"

  if [[ ! -s "$RAW/all_with_perms.txt" ]]; then
    die "No domains to resolve."
  fi

  [[ -f "$RESOLVERS_FILE" && -s "$RESOLVERS_FILE" ]] || die "Resolvers file not found or empty: $RESOLVERS_FILE"

  log "Running massdns (chunked)..."
  split -l "$CHUNK_SIZE" "$RAW/all_with_perms.txt" "$RAW/chunk_"

  > "$RAW/massdns.txt"
  for chunk in "$RAW"/chunk_*; do
    [[ -s "$chunk" ]] || continue
    massdns -r "$RESOLVERS_FILE" -t A -o S "$chunk" >> "$RAW/massdns.txt" || warn "massdns failed for $chunk"
  done

  if [[ "$KEEP_TEMP" -eq 0 ]]; then
    rm -f "$RAW"/chunk_* 2>/dev/null || true
  fi

  awk '$2=="A" { gsub(/\.$/, "", $1); print $1 }' "$RAW/massdns.txt" \
    | sort -u > "$FINAL/resolved.txt"

  COUNT_RES="$(wc -l < "$FINAL/resolved.txt" | tr -d ' ')"
  ok "Resolved subdomains: $COUNT_RES"

  if [[ -s "$FINAL/resolved.txt" ]]; then
    log "Running httpx..."
    httpx -silent \
      -l "$FINAL/resolved.txt" \
      -status-code \
      > "$FINAL/alive.txt" || warn "httpx returned an error"
  fi

  COUNT_ALIVE="$(wc -l < "$FINAL/alive.txt" | tr -d ' ')"

  echo "======================================"
  ok "Total Resolved: $COUNT_RES"
  ok "Alive Hosts:    $COUNT_ALIVE"
  ok "Resolved File:   $FINAL/resolved.txt"
  ok "Alive File:      $FINAL/alive.txt"
  echo "======================================"
}

main "$@"