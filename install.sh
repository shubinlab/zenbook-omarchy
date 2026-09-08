#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible name. New installations should use sh.sh.
canonical_url="https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh"
script_path="${BASH_SOURCE[0]:-}"

if [[ -n "$script_path" && -f "$script_path" ]]; then
  script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd -P)"
  if [[ -x "$script_dir/sh.sh" ]]; then
    exec "$script_dir/sh.sh" "$@"
  fi
fi

command -v curl >/dev/null 2>&1 || {
  printf '%s\n' 'omarchy-profiles: curl is required' >&2
  exit 1
}
temporary="$(mktemp)"
trap 'rm -f "$temporary"' EXIT
curl -fsSL "$canonical_url" -o "$temporary"
exec bash "$temporary" "$@"
