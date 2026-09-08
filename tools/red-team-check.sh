#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

fail() {
  printf 'red-team-check: FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'red-team-check: PASS: %s\n' "$*"
}

expect_reject() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label was accepted"
  fi
  pass "$label rejected"
}

bash -n install.sh scripts/*.sh tools/*.sh profiles/*/voice/*.sh \
  profiles/*/tools/*.sh profiles/*/terminal/*.sh profiles/*/bitwarden/*.sh
pass 'shell syntax'

expect_reject 'option-like OMARCHY_REF' env OMARCHY_REF='--upload-pack=evil' ./install.sh --plan
expect_reject 'path-like OMARCHY_REF' env OMARCHY_REF='../main' ./install.sh --plan
expect_reject 'range-like OMARCHY_REF' env OMARCHY_REF='main..evil' ./install.sh --plan

origin="$(git remote get-url origin 2>/dev/null || true)"
[[ "$origin" == https://github.com/shubinlab/zenbook-omarchy.git ]] ||
  fail "unexpected repository origin: ${origin:-missing}"
pass 'repository origin is allow-listed'

if rg -n --glob '*.sh' \
  '(^|[[:space:]])(cp|mv|install|rm|tee)[^\n]*[[:space:]]/usr/share/omarchy' \
  install.sh scripts profiles; then
  fail 'profile scripts contain a direct write/delete under /usr/share/omarchy'
fi
pass 'no direct writes under /usr/share/omarchy'

if rg -n --glob '*.sh' '\beval[[:space:]]' install.sh scripts profiles; then
  fail 'shell eval found in installer paths'
fi
pass 'no shell eval in installer paths'

while IFS= read -r manifest; do
  while IFS= read -r package; do
    [[ -z "$package" ]] && continue
    [[ "$package" =~ ^[A-Za-z0-9][A-Za-z0-9+._:@/-]*$ ]] ||
      fail "unsafe package entry in $manifest: $package"
  done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
done < <(find profiles -type f -path '*/packages/*.txt' -print)
pass 'package manifests contain only safe package tokens'

./tools/check-public-repo.sh
pass 'public repository scan'

printf '%s\n' 'red-team-check: PASS'
