#!/usr/bin/env bash
set -Eeuo pipefail

# Interactive first-run assistant. It never reads or stores a master password,
# API key or vault item. Those prompts belong to rbw's pinentry and Bitwarden.

STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
ONBOARDING_STATE="${STATE_HOME}/omarchy-profiles/bitwarden/onboarding-complete"
CHROME_STORE_URL="https://chromewebstore.google.com/detail/bitwarden-free-password-m/nngceckbapebfimnlniiiahkandclblb"
FIREFOX_STORE_URL="https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/"
BITWARDEN_DOWNLOAD_URL="https://bitwarden.com/download/"
VAULT_URL="https://vault.bitwarden.com/"
CHROMIUM_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}/chromium"
BITWARDEN_EXTENSION_ID="nngceckbapebfimnlniiiahkandclblb"
CHROMIUM_POLICY_FILE="/etc/chromium/policies/managed/zenbook-omarchy-bitwarden.json"

ACTION=check

die() { printf 'bitwarden-onboarding: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/bitwarden/onboard.sh [--check|--run|--non-interactive]

--check             validate the onboarding asset without changing the system
--run               guide the first login, sync and browser-extension setup
--non-interactive   print the next actions without opening prompts or browsers
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --run) ACTION=run ;;
    --non-interactive) ACTION=non-interactive ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

check_repository() {
  [[ ${CHROME_STORE_URL} == https://chromewebstore.google.com/* ]] || die 'Chrome extension URL is invalid'
  [[ ${FIREFOX_STORE_URL} == https://addons.mozilla.org/* ]] || die 'Firefox extension URL is invalid'
  printf 'bitwarden onboarding check: PASS (no system changes made)\n'
}

print_next_actions() {
  cat <<'EOF'

Bitwarden installed. Finish the one-time setup from this terminal:
  1. Enter your Bitwarden email when asked.
  2. If needed, open Bitwarden Web Vault → Settings → Security → API Key.
  3. Complete `rbw register` using the Bitwarden API-key prompts (not the master password).
  4. Complete the rbw login prompt and sync.
  5. On default Chromium the installer installs the official extension through
     its local policy; otherwise install and log in to the extension manually.

Run the guided flow later with:
  ./scripts/install-bitwarden.sh --profile zenbook-um3406ka
EOF
}

pause() {
  local message=$1
  printf '\n%s\nPress Enter when finished (or Ctrl+C to exit): ' "$message"
  IFS= read -r _ </dev/tty || die 'interactive terminal is required'
}

open_url() {
  local url=$1
  printf 'Opening: %s\n' "$url"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  else
    printf 'Open this link manually: %s\n' "$url"
  fi
}

browser_store_url() {
  local browser
  browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  case "$browser" in
    *firefox*) printf '%s\n' "$FIREFOX_STORE_URL" ;;
    *chromium*|*chrome*|*brave*|*vivaldi*|*edge*) printf '%s\n' "$CHROME_STORE_URL" ;;
    *) printf '%s\n' "$BITWARDEN_DOWNLOAD_URL" ;;
  esac
}

chromium_bitwarden_path() {
  [[ -d ${CHROMIUM_CONFIG_HOME} ]] || return 1
  find "${CHROMIUM_CONFIG_HOME}" -mindepth 3 -maxdepth 3 -type d \
    -name "${BITWARDEN_EXTENSION_ID}" -print -quit 2>/dev/null
}

chromium_policy_configured() {
  [[ -r ${CHROMIUM_POLICY_FILE} ]] &&
    grep -Fq -- "${BITWARDEN_EXTENSION_ID}" "${CHROMIUM_POLICY_FILE}"
}

run_onboarding() {
  [[ -r /dev/tty ]] || die 'guided setup must run from a terminal'
  for command_name in rbw rofi-rbw fuzzel wl-copy wtype; do
    command -v "$command_name" >/dev/null 2>&1 || die "required command not found: $command_name"
  done

  if [[ -e "$ONBOARDING_STATE" ]]; then
    printf 'Bitwarden onboarding is complete; running a quick sync.\n'
    rbw sync || die 'Bitwarden sync failed'
    return 0
  fi

  printf '\nBitwarden onboarding — simple guided setup\n'
  printf 'This assistant never stores secrets; passwords are entered only in Bitwarden pinentry.\n'

  printf '\nStep 1/5. Bitwarden account\n'
  local email
  printf 'Bitwarden email: '
  IFS= read -r email </dev/tty || die 'No email was entered'
  [[ "$email" == *@*.* ]] || die 'The email address looks invalid'
  rbw config set email "$email"

  printf '\nStep 2/5. Sign in on this computer\n'
  if rbw login; then
    printf 'rbw is already registered; sign-in completed.\n'
  else
    printf '\nSign-in did not complete. Is this a new computer that needs one-time registration? [y/N] '
    local register_answer
    IFS= read -r register_answer </dev/tty || die 'No answer was received'
    case "$register_answer" in
      y|Y|yes|YES) ;;
      *) die 'Sign-in failed; check the email, Bitwarden server and master password, then run onboarding again' ;;
    esac
    printf '\nOne-time device registration is required.\n'
    printf 'If rbw asks for an API key, get it from Bitwarden Web Vault → Settings → Security → API Key.\n'
    pause 'Open the Web Vault and prepare the API key'
    rbw register || die 'rbw registration failed; check the API key and run onboarding again'
    rbw login || die 'rbw sign-in failed; run onboarding again'
  fi
  rbw sync || die 'Bitwarden sync failed'
  printf 'Vault synchronized.\n'

  printf '\nStep 3/5. Browser extension\n'
  local store_url chromium_extension_path
  chromium_extension_path="$(chromium_bitwarden_path || true)"
  if [[ -n ${chromium_extension_path} ]]; then
    printf 'The official Bitwarden extension is already installed in Chromium: %s\n' "$chromium_extension_path"
    printf 'Make sure it is enabled and pinned to the browser toolbar.\n'
  elif chromium_policy_configured; then
    printf 'The Chromium automatic-install policy is already configured.\n'
    pause 'Close all Chromium windows and start Chromium again; the extension will install automatically'
    if chromium_extension_path="$(chromium_bitwarden_path || true)"; then
      printf 'Bitwarden is now available in Chromium: %s\n' "$chromium_extension_path"
    else
      printf 'Chromium has not shown the extension yet; check chrome://policy after restarting.\n'
    fi
  else
    store_url="$(browser_store_url)"
    open_url "$store_url"
    pause 'In the store, click Add/Install for the official Bitwarden Password Manager'
  fi

  printf '\nStep 4/5. First extension launch\n'
  open_url "$VAULT_URL"
  pause 'Sign in to the Bitwarden extension and pin it to the browser toolbar'

  printf '\nStep 5/5. Omarchy check\n'
  printf 'Open a safe text field, press Super + Shift + /, select a test entry and press Enter.\n'
  pause 'After the username/password is entered successfully in the test field'

  mkdir -p -m 0700 "$(dirname -- "$ONBOARDING_STATE")"
  : >"$ONBOARDING_STATE"
  chmod 600 "$ONBOARDING_STATE"
  printf '\nDone: Bitwarden is synchronized, the extension is installed and the hotkey works.\n'
}

case "$ACTION" in
  check) check_repository ;;
  non-interactive) check_repository; print_next_actions ;;
  run) check_repository; run_onboarding ;;
esac
