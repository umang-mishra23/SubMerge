#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

# ========================
# SubMerge - Unified Recon Framework
# Author: Umang Mishra
# Version: 2.0
# Legal: Use only on targets you own or have permission to test.
# =========================

SCRIPT_NAME="$(basename "$0")"

DOMAIN=""
OUTPUT_ROOT="."
RESOLVERS_FILE="$SCRIPT_DIR/resolvers.txt"

DEEP_MODE=0
CHUNK_SIZE=50000
DNSGEN_LIMIT=5000
MASSDNS_CONCURRENCY=50
ENUM_TIMEOUT="15m"
KEEP_TEMP=0

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%b[*]%b %s\n' "$BLUE" "$NC" "$*"; }
ok()   { printf '%b[+]%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b[!]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
fail() { printf '%b[x]%b %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

banner() {
cat <<'EOF'

   ███████╗██╗   ██╗██████╗ ███╗   ███╗███████╗██████╗  ██████╗ ███████╗
   ██╔════╝██║   ██║██╔══██╗████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝
   ███████╗██║   ██║██████╔╝██║████╔██║█████╗  ██████╔╝██║  ███╗█████╗
   ╚════██║██║   ██║██╔══██╗██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝
   ███████║╚██████╔╝██████╔╝██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗
   ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        SubMerge - Unified Recon Framework
                  Version 2.0
                  Author: Umang Mishra

   [!] Legal: Use only on targets you own or have permission to test!
EOF
}

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME example.com
  $SCRIPT_NAME example.com --deep
  $SCRIPT_NAME example.com --deep --dnsgen-limit 10000 --massdns-concurrency 50

Options:
  --deep                      Enable dnsgen + massdns pipeline
  --output, -o DIR            Output directory (default: current directory)
  --resolvers FILE            Resolver list (default: resolvers.txt)
  --chunk-size N              Lines per massdns chunk (default: 50000)
  --dnsgen-limit N            Max permutations (default: 5000)
  --massdns-concurrency N     MassDNS concurrency (default: 50)
  --timeout DURATION           Enum timeout like 10m, 15m (default: 15m)
  --keep-temp                 Keep temp files
  -h, --help                  Show help
EOF
}

have() {
  command -v "$1" >/dev/null 2>&1
}

require_cmds_fast() {
  local missing=()
  local cmds=(amass subfinder assetfinder findomain httpx sort awk sed wc cat grep tee timeout)

  for c in "${cmds[@]}"; do
    have "$c" || missing+=("$c")
  done

  if ((${#missing[@]} > 0)); then
    fail "Missing required tools: ${missing[*]}"
  fi
}

require_cmds_deep() {
  local missing=()
  local cmds=(dnsgen massdns split)

  for c in "${cmds[@]}"; do
    have "$c" || missing+=("$c")
  done

  if ((${#missing[@]} > 0)); then
    fail "Missing deep-mode tools: ${missing[*]}"
  fi
}

validate_domain() {
  [[ -n "$DOMAIN" ]] || fail "No domain provided"
  [[ "$DOMAIN" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || fail "Invalid domain: $DOMAIN"
}

BASE=""
RAW=""
FINAL=""
TMP_DIR=""
LOG_FILE=""

cleanup() {
  if [[ "$KEEP_TEMP" -eq 0 ]]; then
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR" 2>/dev/null || true
    [[ -n "${RAW:-}" ]] && rm -f "$RAW"/chunk_* 2>/dev/null || true
  fi
}
trap cleanup EXIT

parse_args() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --deep)
        DEEP_MODE=1
        shift
        ;;
      --output|-o)
        OUTPUT_ROOT="${2:-}"
        [[ -n "${OUTPUT_ROOT:-}" ]] || fail "--output needs a value"
        shift 2
        ;;
      --resolvers)
        RESOLVERS_FILE="${2:-}"
        [[ -n "${RESOLVERS_FILE:-}" ]] || fail "--resolvers needs a value"
        shift 2
        ;;
      --chunk-size)
        CHUNK_SIZE="${2:-}"
        [[ -n "${CHUNK_SIZE:-}" ]] || fail "--chunk-size needs a value"
        shift 2
        ;;
      --dnsgen-limit)
        DNSGEN_LIMIT="${2:-}"
        [[ -n "${DNSGEN_LIMIT:-}" ]] || fail "--dnsgen-limit needs a value"
        shift 2
        ;;
      --massdns-concurrency)
        MASSDNS_CONCURRENCY="${2:-}"
        [[ -n "${MASSDNS_CONCURRENCY:-}" ]] || fail "--massdns-concurrency needs a value"
        shift 2
        ;;
      --timeout)
        ENUM_TIMEOUT="${2:-}"
        [[ -n "${ENUM_TIMEOUT:-}" ]] || fail "--timeout needs a value"
        shift 2
        ;;
      --keep-temp)
        KEEP_TEMP=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -z "$DOMAIN" ]]; then
          DOMAIN="$1"
          shift
        else
          fail "Unknown argument: $1"
        fi
        ;;
    esac
  done
}

start_job() {
  local label="$1"
  shift
  info "$label..."
  "$@" &
  pids+=("$!")
}

run_amass() {
  timeout "$ENUM_TIMEOUT" amass enum -passive -d "$DOMAIN" > "$RAW/amass.txt" 2>>"$LOG_FILE" || true
}

run_subfinder() {
  timeout "$ENUM_TIMEOUT" subfinder -d "$DOMAIN" -silent -o "$RAW/subfinder.txt" 2>>"$LOG_FILE" || true
}

run_assetfinder() {
  timeout "$ENUM_TIMEOUT" assetfinder --subs-only "$DOMAIN" > "$RAW/assetfinder.txt" 2>>"$LOG_FILE" || true
}

run_findomain() {
  timeout "$ENUM_TIMEOUT" findomain -t "$DOMAIN" -q > "$RAW/findomain.txt" 2>>"$LOG_FILE" || true
}

main() {
  parse_args "$@"
  banner
  validate_domain
  require_cmds_fast
  [[ "$DEEP_MODE" -eq 1 ]] && require_cmds_deep

  if [[ "$DEEP_MODE" -eq 1 ]]; then
      ENUM_TIMEOUT="10m"
  else
      ENUM_TIMEOUT="3m"
  fi

  if [[ "$OUTPUT_ROOT" = "." ]]; then
      OUTPUT_ROOT="$(pwd)"
  fi

  BASE="${OUTPUT_ROOT%/}/$DOMAIN"
  RAW="$BASE/raw"
  FINAL="$BASE/final"
  TMP_DIR="$(mktemp -d)"
  LOG_FILE="$BASE/run.log"

  mkdir -p "$RAW" "$FINAL"
  : > "$LOG_FILE"

  exec > >(tee -a "$LOG_FILE") 2>&1

  info "Target: $DOMAIN"
  info "Output: $BASE"
  [[ "$DEEP_MODE" -eq 1 ]] && info "Mode: deep" || info "Mode: fast"

  : > "$RAW/amass.txt"
  : > "$RAW/subfinder.txt"
  : > "$RAW/assetfinder.txt"
  : > "$RAW/findomain.txt"
  : > "$RAW/massdns.txt"
  : > "$FINAL/resolved.txt"
  : > "$FINAL/alive.txt"

  pids=()

  start_job "amass" run_amass
  start_job "subfinder" run_subfinder
  start_job "assetfinder" run_assetfinder
  start_job "findomain" run_findomain

  failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
      warn "One enumeration job failed or timed out"
    fi
  done

  [[ "$failed" -eq 1 ]] && warn "Continuing with whatever output was collected"

  cat "$RAW"/amass.txt \
      "$RAW"/subfinder.txt \
      "$RAW"/assetfinder.txt \
      "$RAW"/findomain.txt 2>/dev/null \
    | sed 's/\r$//' \
    | awk 'NF' \
    | sort -u > "$RAW/all_initial.txt"

  COUNT_INIT="$(wc -l < "$RAW/all_initial.txt" | tr -d ' ')"
  ok "Subdomains found: $COUNT_INIT"

  if [[ "$COUNT_INIT" -eq 0 ]]; then
    fail "No passive subdomains found. Check connectivity, tool setup, or target scope."
  fi

  HTTPX_INPUT="$RAW/all_initial.txt"

  if [[ "$DEEP_MODE" -eq 1 ]]; then
    ENUM_TIMEOUT="15m"

    info "Running dnsgen..."
    dnsgen "$RAW/all_initial.txt" \
      | sed 's/\r$//' \
      | awk 'NF' \
      | sort -u \
      | awk -v limit="$DNSGEN_LIMIT" 'NR<=limit' > "$RAW/dnsgen.txt" 2>>"$LOG_FILE" || true

    if [[ -s "$RAW/dnsgen.txt" ]]; then
      cat "$RAW/all_initial.txt" "$RAW/dnsgen.txt" \
        | sed 's/\r$//' \
        | awk 'NF' \
        | sort -u > "$RAW/all_final.txt"
    else
      cp "$RAW/all_initial.txt" "$RAW/all_final.txt"
      warn "dnsgen produced no output; using passive results only"
    fi

    COUNT_FINAL="$(wc -l < "$RAW/all_final.txt" | tr -d ' ')"
    ok "Total after permutations: $COUNT_FINAL"

    if [[ -f "$RESOLVERS_FILE" && -s "$RESOLVERS_FILE" ]]; then
      grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$RESOLVERS_FILE" \
        | sort -u > "$TMP_DIR/resolvers.clean.txt"

      if [[ -s "$TMP_DIR/resolvers.clean.txt" ]]; then
        info "Resolving subdomains..."
        split -l "$CHUNK_SIZE" "$RAW/all_final.txt" "$TMP_DIR/chunk_"

        : > "$RAW/massdns.txt"
        for chunk in "$TMP_DIR"/chunk_*; do
          [[ -s "$chunk" ]] || continue
          massdns \
            -r "$TMP_DIR/resolvers.clean.txt" \
            -t A \
            -o S \
            -s "$MASSDNS_CONCURRENCY" \
            "$chunk" \
            >> "$RAW/massdns.txt" 2>>"$LOG_FILE" || warn "massdns failed for $chunk"
        done

        awk '$2=="A" { gsub(/\.$/, "", $1); print $1 }' "$RAW/massdns.txt" \
          | sort -u > "$FINAL/resolved.txt"

        if [[ -s "$FINAL/resolved.txt" ]]; then
          HTTPX_INPUT="$FINAL/resolved.txt"
        else
          warn "MassDNS produced no resolved hosts; falling back to dnsgen/passive list for httpx"
          HTTPX_INPUT="$RAW/all_final.txt"
        fi
      else
        warn "No valid resolvers found in $RESOLVERS_FILE; skipping massdns"
        HTTPX_INPUT="$RAW/all_final.txt"
      fi
    else
      warn "Resolvers file missing or empty; skipping massdns"
      HTTPX_INPUT="$RAW/all_final.txt"
    fi
  fi

  if [[ "$DEEP_MODE" -eq 0 ]]; then
    cp "$RAW/all_initial.txt" "$RAW/all_final.txt"
  fi

  info "Checking live hosts..."
  httpx -silent \
    -l "$HTTPX_INPUT" \
    -status-code \
    > "$FINAL/alive.txt" 2>>"$LOG_FILE" || warn "httpx returned an error"

  COUNT_ALIVE="$(wc -l < "$FINAL/alive.txt" | tr -d ' ')"
  ok "Alive hosts: $COUNT_ALIVE"

  if [[ "$DEEP_MODE" -eq 0 ]]; then
    warn "Fast mode skips dnsgen and massdns. resolved.txt will remain empty."
  fi

  echo
  echo "======================================"
  ok "Scan Completed Successfully"
  echo
  info "Output Directory : $BASE"
  info "Raw Results      : $RAW"
  info "Final Results    : $FINAL"

  if [[ "$DEEP_MODE" -eq 1 ]]; then
    info "Resolved Hosts   : $FINAL/resolved.txt"
  fi

  info "Alive Hosts      : $FINAL/alive.txt"
  info "Log File         : $LOG_FILE"
  echo "======================================"
}

main "$@"
