#!/usr/bin/env bash
set -euo pipefail

profile="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/profiles/zenbook-um3406ka/voice/voxtype-omarchy.env.example"
# shellcheck disable=SC1090
source "${profile}"

[[ "${VOICE_AUDIO_DEVICE}" == pipewire ]]
[[ "${VOICE_OUTPUT_MODE}" == paste ]]

printf '%s\n' 'voice policy contract: PASS'
