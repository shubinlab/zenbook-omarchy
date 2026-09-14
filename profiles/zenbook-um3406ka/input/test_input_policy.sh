#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/xkb" "$XDG_CONFIG_HOME/fcitx5" "$TEST_ROOT/bin"
cp "$ROOT_DIR/profiles/zenbook-um3406ka/input/input.lua" "$XDG_CONFIG_HOME/hypr/input.lua"
cp "$ROOT_DIR/profiles/zenbook-um3406ka/input/bindings-block.lua" "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$ROOT_DIR/profiles/zenbook-um3406ka/input/fcitx5-profile" "$XDG_CONFIG_HOME/fcitx5/profile"
cat >"$XDG_CONFIG_HOME/xkb/voxtype-keymap.xkb" <<'EOF'
xkb_keymap {
    xkb_keycodes { include "evdev+aliases(qwerty)" };
    xkb_types { include "complete" };
    xkb_compat { include "complete" };
    xkb_symbols { include "pc+us" };
    xkb_geometry { include "pc(pc104)" };
};
EOF

cat >"$TEST_ROOT/bin/xkbcli" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TEST_ROOT/bin/fcitx5-remote" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-n" ]] && printf '%s\n' keyboard-us
EOF
cat >"$TEST_ROOT/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TEST_ROOT/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *' is-enabled omarchy-fcitx5.service '*) printf '%s\n' enabled ;;
  *' is-active omarchy-fcitx5.service '*) printf '%s\n' active ;;
  *' show omarchy-fcitx5.service '* ) printf '%s\n' '/usr/bin/fcitx5 --disable notificationitem' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin"/*
export PATH="$TEST_ROOT/bin:$PATH"

doctor="$ROOT_DIR/profiles/zenbook-um3406ka/input/doctor.sh"

cat >"$XDG_CONFIG_HOME/fcitx5/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
# Layout
# Layout=

[GroupOrder]
0=Default
EOF
"$doctor" >/dev/null

cp "$ROOT_DIR/profiles/zenbook-um3406ka/input/fcitx5-profile" "$XDG_CONFIG_HOME/fcitx5/profile"
"$doctor" >/dev/null

sed -i 's/keyboard-us/keyboard-ru/g' "$XDG_CONFIG_HOME/fcitx5/profile"
cat >>"$XDG_CONFIG_HOME/fcitx5/profile" <<'EOF'

[Groups/0/Items/0]
Name=keyboard-ru
EOF
if "$doctor" >/dev/null 2>&1; then
  printf '%s\n' 'input policy test: keyboard-ru must remain rejected' >&2
  exit 1
fi

printf '%s\n' 'input policy test: native keyboard-us fallback accepted; keyboard-ru rejected'
