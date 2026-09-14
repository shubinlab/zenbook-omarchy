#!/usr/bin/env bash
set -euo pipefail

unit="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/searxng.service"

test -f "${unit}"
! grep -Eq '/(home|root)/' "${unit}"
grep -Fq '@SEARXNG_DIR@' "${unit}"
grep -Fq 'Requires=docker.service' "${unit}"
grep -Fq -- '--wait' "${unit}"

printf '%s\n' 'search unit contract: PASS'
