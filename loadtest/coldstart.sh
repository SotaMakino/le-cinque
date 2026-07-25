#!/usr/bin/env bash
# Measure cold-start vs warm latency for a deployed server, and log every run.
#
# Cold start = time-to-first-byte of the FIRST request after the service has
# been idle long enough to spin down (Render free: ~15 min; Cloud Run without
# min-instances: ~15 min). A load test can't see this — it warms the server on
# request #1 and then only measures warm latency. So we use a single curl.
#
# We hit an UNREGISTERED path (/_coldping) on purpose: it returns 404 from the
# booted server, so the number is pure boot + network — no DB, no auth.
#
# Every run is appended to loadtest/coldstart-results.csv so before (Render) and
# after (Cloud Run) numbers pile up in one place for comparison.
#
# Usage:
#   ./coldstart.sh https://your-app.onrender.com        # cold: run after >15 min idle
#   ./coldstart.sh https://your-app.onrender.com warm   # warm: 5 back-to-back reqs
set -euo pipefail

BASE="${1:?usage: coldstart.sh <base-url> [warm]}"
MODE="${2:-cold}"
URL="${BASE%/}/_coldping"
HOST="$(printf '%s' "$BASE" | sed -E 's#^https?://##; s#/.*$##')"

RESULTS="$(dirname "$0")/coldstart-results.csv"
if [ ! -f "$RESULTS" ]; then
  echo "timestamp,host,mode,dns_s,connect_s,tls_s,ttfb_s,total_s,http_code" > "$RESULTS"
fi

# One request: append a CSV row and print a human-readable line.
ping_once() {
  local label="$1"
  # Raw comma-separated timings for the CSV.
  local raw
  raw="$(curl -s -o /dev/null \
    -w '%{time_namelookup},%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total},%{http_code}' \
    "$URL")"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "$ts,$HOST,$MODE,$raw" >> "$RESULTS"

  # Same numbers, readable.
  IFS=',' read -r dns connect tls ttfb total code <<< "$raw"
  printf '  %sDNS %ss  connect %ss  TLS %ss  TTFB %ss  total %ss  (HTTP %s)\n' \
    "$label" "$dns" "$connect" "$tls" "$ttfb" "$total" "$code"
}

if [ "$MODE" = "warm" ]; then
  echo "WARM baseline — 5 back-to-back requests to $URL"
  for i in 1 2 3 4 5; do ping_once "#$i "; done
else
  echo "COLD start — single request to $URL"
  echo "(make sure the service has been idle >15 min so it actually spun down)"
  ping_once ""
fi

echo "→ logged to $RESULTS"
