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
  5. Install and log in to the official browser extension.

Run the guided flow later with:
  ./scripts/install-bitwarden.sh --profile zenbook-um3406ka
EOF
}

pause() {
  local message=$1
  printf '\n%s\nНажмите Enter, когда закончите (или Ctrl+C для выхода): ' "$message"
  IFS= read -r _ </dev/tty || die 'interactive terminal is required'
}

open_url() {
  local url=$1
  printf 'Открываю: %s\n' "$url"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  else
    printf 'Откройте ссылку вручную: %s\n' "$url"
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

run_onboarding() {
  [[ -r /dev/tty ]] || die 'guided setup must run from a terminal'
  for command_name in rbw rofi-rbw fuzzel wl-copy wtype; do
    command -v "$command_name" >/dev/null 2>&1 || die "required command not found: $command_name"
  done

  if [[ -e "$ONBOARDING_STATE" ]]; then
    printf 'Bitwarden onboarding уже завершён; выполняю быструю синхронизацию.\n'
    rbw sync || die 'синхронизация Bitwarden не завершилась'
    return 0
  fi

  printf '\nBitwarden onboarding — короткий пошаговый режим\n'
  printf 'Секреты не записываются этим скриптом: пароль вводится только в pinentry Bitwarden.\n'

  printf '\nШаг 1/5. Аккаунт Bitwarden\n'
  local email
  printf 'Введите email Bitwarden: '
  IFS= read -r email </dev/tty || die 'email was not entered'
  [[ "$email" == *@*.* ]] || die 'похоже, email введён неверно'
  rbw config set email "$email"

  printf '\nШаг 2/5. Вход на этом компьютере\n'
  if rbw login; then
    printf 'rbw уже зарегистрирован — вход выполнен.\n'
  else
    printf '\nВход не выполнен. Это новый компьютер, которому нужна одноразовая регистрация? [д/Н] '
    local register_answer
    IFS= read -r register_answer </dev/tty || die 'ответ не получен'
    case "$register_answer" in
      д|Д|да|ДА|y|Y|yes|YES) ;;
      *) die 'вход не выполнен; проверьте email, сервер Bitwarden и мастер-пароль, затем повторите onboarding' ;;
    esac
    printf '\nНужна одноразовая регистрация устройства.\n'
    printf 'Если rbw попросит API key, возьмите его в Bitwarden Web Vault → Settings → Security → API Key.\n'
    pause 'Откройте Web Vault и подготовьте API key'
    rbw register || die 'регистрация rbw не завершилась; повторите этот onboarding после проверки API key'
    rbw login || die 'вход rbw не завершился; повторите onboarding'
  fi
  rbw sync || die 'синхронизация Bitwarden не завершилась'
  printf 'Vault синхронизирован.\n'

  printf '\nШаг 3/5. Расширение браузера\n'
  local store_url
  store_url="$(browser_store_url)"
  open_url "$store_url"
  pause 'В магазине нажмите Add/Установить для официального Bitwarden Password Manager'

  printf '\nШаг 4/5. Первый запуск расширения\n'
  open_url "$VAULT_URL"
  pause 'В браузере войдите в расширение Bitwarden и закрепите его на панели'

  printf '\nШаг 5/5. Проверка Omarchy\n'
  printf 'Откройте безопасное текстовое поле, нажмите Super + Shift + /, выберите тестовую запись и нажмите Enter.\n'
  pause 'После успешного ввода логина/пароля в тестовое поле'

  mkdir -p -m 0700 "$(dirname -- "$ONBOARDING_STATE")"
  : >"$ONBOARDING_STATE"
  chmod 600 "$ONBOARDING_STATE"
  printf '\nГотово: Bitwarden синхронизирован, расширение установлено, хоткей проверен.\n'
}

case "$ACTION" in
  check) check_repository ;;
  non-interactive) check_repository; print_next_actions ;;
  run) check_repository; run_onboarding ;;
esac
