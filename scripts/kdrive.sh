#!/usr/bin/env bash
set -euo pipefail

KDRIVE_VERSION='3.8.7.1'
KDRIVE_RELEASE_TAG='kdrive-3.8.7.1-native-arch'
KDRIVE_ARCHIVE_NAME="kdrive-${KDRIVE_VERSION}-native-arch.tar.zst"
KDRIVE_ARCHIVE_URL="https://github.com/shubinlab/zenbook-omarchy/releases/download/${KDRIVE_RELEASE_TAG}/${KDRIVE_ARCHIVE_NAME}"
KDRIVE_SHA256='e1212cc39c4ef00725f1a7a13cf04537fb49c01014fb9a81ce436ae7f5f0fb48'

KDRIVE_ROOT="${HOME}/.local/share/kdrive/${KDRIVE_VERSION}"
KDRIVE_BIN_DIR="${HOME}/.local/bin"
KDRIVE_DESKTOP_DIR="${HOME}/.local/share/applications"

die() {
  printf 'kDrive installer: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${KDRIVE_TEMP_DIR:-}" ]]; then
    rm -rf -- "$KDRIVE_TEMP_DIR"
  fi
}

usage() {
  cat <<'HELP'
Native Arch kDrive 3.8.7.1 installer

Usage:
  scripts/kdrive.sh [--install|--check|--uninstall]

Options:
  --install       Download, verify and install kDrive (default).
  --check         Check host architecture, tools and an existing install.
  --uninstall     Remove only this kDrive version and its launchers.
  -h, --help      Show this help.

For an offline install, set KDRIVE_ARCHIVE to the downloaded .tar.zst file.
The installer is user-scoped and does not write to system directories.
HELP
}

require_commands() {
  local command_name
  for command_name in curl tar zstd sha256sum ldd install sed; do
    command -v "$command_name" >/dev/null 2>&1 ||
      die "required command is missing: $command_name"
  done
}

check_architecture() {
  [[ "$(uname -m)" == x86_64 ]] ||
    die "this build supports x86_64 only (detected $(uname -m))"
}

check_binary() {
  local binary="$1"
  local missing

  [[ -x "$binary" ]] || die "installed binary is missing: $binary"
  missing="$(ldd "$binary" 2>&1 | awk '/not found/ { print; }')"
  [[ -z "$missing" ]] || {
    printf '%s\n' "$missing" >&2
    die "missing runtime libraries for $binary"
  }
}

check_payload() {
  local root="$1"
  local forbidden

  [[ -x "$root/bin/kDrive" ]] || die 'archive does not contain bin/kDrive'
  [[ -x "$root/bin/kDrive_client" ]] || die 'archive does not contain bin/kDrive_client'
  [[ -f "$root/share/applications/kDrive_client.desktop" ]] ||
    die 'archive does not contain the kDrive desktop entry'

  forbidden="$(find "$root" -type f \( \
    -name 'libldap*' -o -name 'liblber*' -o -name 'libsasl2*' -o -iname '*crashpad*' \
  \) -print -quit)"
  [[ -z "$forbidden" ]] || die "forbidden bundled artifact found: $forbidden"

  check_binary "$root/bin/kDrive"
  check_binary "$root/bin/kDrive_client"
}

check_install() {
  check_architecture
  require_commands
  if [[ -d "$KDRIVE_ROOT" ]]; then
    check_payload "$KDRIVE_ROOT"
    "$KDRIVE_ROOT/bin/kDrive" --version
    printf '%s\n' "kDrive check: PASS ($KDRIVE_ROOT)"
  else
    printf '%s\n' "kDrive check: host ready; version $KDRIVE_VERSION is not installed"
  fi
}

install_kdrive() {
  local temp_dir archive payload desktop_file

  check_architecture
  require_commands
  temp_dir="$(mktemp -d)"
  KDRIVE_TEMP_DIR="$temp_dir"
  trap cleanup EXIT
  archive="$temp_dir/$KDRIVE_ARCHIVE_NAME"

  if [[ -n "${KDRIVE_ARCHIVE:-}" ]]; then
    [[ -f "$KDRIVE_ARCHIVE" ]] || die "KDRIVE_ARCHIVE does not exist: $KDRIVE_ARCHIVE"
    cp -- "$KDRIVE_ARCHIVE" "$archive"
  else
    printf '%s\n' "Downloading $KDRIVE_ARCHIVE_NAME"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
      "$KDRIVE_ARCHIVE_URL" --output "$archive"
  fi

  printf '%s  %s\n' "$KDRIVE_SHA256" "$archive" | sha256sum --check --status ||
    die 'archive checksum mismatch'

  tar --zstd --extract --file "$archive" --directory "$temp_dir"
  payload="$temp_dir/kdrive-${KDRIVE_VERSION}-native-arch"
  check_payload "$payload"

  install -d "$(dirname -- "$KDRIVE_ROOT")" "$KDRIVE_BIN_DIR" "$KDRIVE_DESKTOP_DIR"
  if [[ -e "$KDRIVE_ROOT" || -L "$KDRIVE_ROOT" ]]; then
    rm -rf -- "$KDRIVE_ROOT"
  fi
  mv -- "$payload" "$KDRIVE_ROOT"

  ln -sfn -- "$KDRIVE_ROOT/bin/kDrive" "$KDRIVE_BIN_DIR/kDrive"
  ln -sfn -- "$KDRIVE_ROOT/bin/kDrive_client" "$KDRIVE_BIN_DIR/kDrive_client"

  desktop_file="$temp_dir/kDrive.desktop"
  sed "s|^Exec=kDrive$|Exec=$KDRIVE_BIN_DIR/kDrive|" \
    "$KDRIVE_ROOT/share/applications/kDrive_client.desktop" > "$desktop_file"
  install -m 0644 "$desktop_file" "$KDRIVE_DESKTOP_DIR/kDrive.desktop"

  printf '%s\n' "kDrive $KDRIVE_VERSION installed in $KDRIVE_ROOT"
  printf '%s\n' "Launch: $KDRIVE_BIN_DIR/kDrive or the kDrive desktop entry"
}

uninstall_kdrive() {
  rm -f -- "$KDRIVE_BIN_DIR/kDrive" "$KDRIVE_BIN_DIR/kDrive_client" \
    "$KDRIVE_DESKTOP_DIR/kDrive.desktop"
  if [[ -e "$KDRIVE_ROOT" || -L "$KDRIVE_ROOT" ]]; then
    rm -rf -- "$KDRIVE_ROOT"
  fi
  printf '%s\n' "Removed kDrive $KDRIVE_VERSION and its user launchers"
}

action=install
for argument in "$@"; do
  case "$argument" in
    --install) action=install ;;
    --check) action=check ;;
    --uninstall) action=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $argument (use --help)" ;;
  esac
done

case "$action" in
  check) check_install ;;
  install) install_kdrive ;;
  uninstall) uninstall_kdrive ;;
esac
