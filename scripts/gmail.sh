#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(
  gnome-control-center
  geary
  gnome-calendar
  gnome-contacts
)

die() {
  printf 'gmail installer: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'HELP'
Native Google desktop apps for Omarchy

Usage:
  scripts/gmail.sh [--install|--check|--plan]

Options:
  --install       Install the native GNOME mail, calendar, contacts and
                  Online Accounts settings applications (default).
  --check         Verify the packages, binaries and desktop entries.
  --plan          Print the package set without changing the system.
  -h, --help      Show this help.

The installer does not change Google accounts or credentials. Configure or
reuse them through GNOME Online Accounts after installation.
KDrive is maintained by its separate GitHub Release and installer.
HELP
}

check_commands() {
  local command_name
  for command_name in omarchy-pkg-add pacman; do
    command -v "$command_name" >/dev/null 2>&1 ||
      die "required command is missing: $command_name"
  done
}

check_install() {
  local package command_name desktop

  for package in "${PACKAGES[@]}"; do
    pacman -Q "$package" >/dev/null 2>&1 ||
      die "package is not installed: $package"
  done

  for command_name in gnome-control-center geary gnome-calendar gnome-contacts; do
    command -v "$command_name" >/dev/null 2>&1 ||
      die "command is missing: $command_name"
  done

  for desktop in \
    /usr/share/applications/org.gnome.Settings.desktop \
    /usr/share/applications/org.gnome.Geary.desktop \
    /usr/share/applications/org.gnome.Calendar.desktop \
    /usr/share/applications/org.gnome.Contacts.desktop; do
    [[ -f "$desktop" ]] || die "desktop entry is missing: $desktop"
  done

  printf '%s\n' 'gmail installer: PASS (native Google desktop apps are installed)'
}

install_apps() {
  check_commands
  printf 'gmail installer: installing/verifying %d native packages\n' "${#PACKAGES[@]}"
  omarchy-pkg-add "${PACKAGES[@]}"
  check_install
}

action=install
for argument in "$@"; do
  case "$argument" in
    --install) action=install ;;
    --check) action=check ;;
    --plan) action=plan ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $argument (use --help)" ;;
  esac
done

case "$action" in
  check)
    check_commands
    check_install
    ;;
  plan)
    printf '%s\n' 'gmail installer: no changes; native package plan:'
    printf '  %s\n' "${PACKAGES[@]}"
    ;;
  install)
    install_apps
    ;;
esac
