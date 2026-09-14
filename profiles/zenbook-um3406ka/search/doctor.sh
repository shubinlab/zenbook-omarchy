#!/usr/bin/env bash
set -euo pipefail

base_url="${SEARXNG_URL:-http://127.0.0.1:8080}"
if [[ "$(systemctl is-enabled searxng.service 2>/dev/null || true)" != enabled ]]; then
  printf '%s\n' 'searxng.service=not-enabled' >&2
  exit 1
fi
if [[ "$(systemctl is-active searxng.service 2>/dev/null || true)" != active ]]; then
  printf '%s\n' 'searxng.service=not-active' >&2
  exit 1
fi
if [[ "$(systemctl is-active docker.service 2>/dev/null || true)" != active ]]; then
  printf '%s\n' 'docker.service=not-active' >&2
  exit 1
fi
curl --fail --silent --show-error --max-time 5 "$base_url/healthz" >/dev/null
command -v searxng-search >/dev/null
searxng-search --raw --limit 1 "omarchy" | jq -e '.query == "omarchy" and (.results | type == "array")' >/dev/null
searxng-search --limit 1 "omarchy" | jq -e '.instance == "http://127.0.0.1:8080" and (.results | type == "array")' >/dev/null
printf '%s\n' 'searxng-search=ok'
