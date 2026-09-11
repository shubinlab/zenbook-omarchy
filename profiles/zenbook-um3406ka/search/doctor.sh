#!/usr/bin/env bash
set -euo pipefail

base_url="${SEARXNG_URL:-http://127.0.0.1:8080}"
curl --fail --silent --show-error --max-time 5 "$base_url/healthz" >/dev/null
command -v searxng-search >/dev/null
searxng-search --raw --limit 1 "omarchy" | jq -e '.query == "omarchy" and (.results | type == "array")' >/dev/null
searxng-search --limit 1 "omarchy" | jq -e '.instance == "http://127.0.0.1:8080" and (.results | type == "array")' >/dev/null
printf '%s\n' 'searxng-search=ok'
