#!/usr/bin/env bash
set -Eeuo pipefail

# Conservative, local-only post-processing for technical dictation.
#
# This is intentionally a named Voxtype profile rather than the global
# post-process hook. It never calls a network service or an LLM and only fixes
# a small set of unambiguous spoken forms used by this host. A future local
# LLM can replace this command in the technical profile without changing the
# native capture, service or output path.

input="$(cat)"
[[ -n "${input}" ]] || exit 0

printf '%s' "${input}" |
  sed -E \
    -e 's/(^|[[:space:][:punct:]])[Оо]марч[ииыы]([[:space:][:punct:]]|$)/\1Omarchy\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Вв]окстайп([[:space:][:punct:]]|$)/\1Voxtype\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Лл]имонад([[:space:][:punct:]]|$)/\1Lemonade\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Фф]астфлоу[[:space:]-]*[Ээ]л[Ээ]м([[:space:][:punct:]]|$)/\1FastFlowLM\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Хх]айпрленд([[:space:][:punct:]]|$)/\1Hyprland\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Пп]айп[Вв]айр([[:space:][:punct:]]|$)/\1PipeWire\2/g' \
    -e 's/(^|[[:space:][:punct:]])[Вв]айр[Пп]л[Ээ]мб[Ээ]р([[:space:][:punct:]]|$)/\1WirePlumber\2/g'
