#!/usr/bin/env bash
# Scenario tests for the WezTerm step of nvim_forge/scripts/install-linux.sh
# (WT-LOAD-13; change add-linux-installer-parity, Decision 5): sandbox HOME,
# `env -i`, DISPLAY=:0, FORGE_NVIM_SKIP_DEPS=1, FORGE_NVIM_DEPS_ONLY=1, shims,
# no network. L11 runs the Linux command from the wezterm.lua header itself.
# Покрывает openspec/specs/wezterm-config-loading (WT-LOAD-13).
# Нужны: POSIX-окружение с bash (WSL/Linux).
# usage: tests/install-linux.scenarios.sh [repo-root] [bash-binary]
#   bash-binary — например, собранный bash 3.2.57 (общий файл функций
#   исполняет и macOS).
set -u
REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
BASH_BIN="${2:-bash}"
ROOT="$(mktemp -d /tmp/forge-linux-test.XXXXXX)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1  [$2]"; fi; }

mk_checkout() {
  local c="$1"
  mkdir -p "$c/nvim_forge/scripts" "$c/nvim_forge/lua"
  cp "$REPO/wezterm.lua" "$c/wezterm.lua"
  cp "$REPO/nvim_forge.sh" "$c/nvim_forge.sh"
  cp "$REPO/nvim_forge/scripts/install-linux.sh" "$c/nvim_forge/scripts/install-linux.sh"
  cp "$REPO/nvim_forge/scripts/setup-stage.lua" "$c/nvim_forge/scripts/setup-stage.lua"
  if [ -d "$REPO/nvim_forge/scripts/lib" ]; then cp -R "$REPO/nvim_forge/scripts/lib" "$c/nvim_forge/scripts/lib"; fi
  : > "$c/nvim_forge/init.lua"
}

mk_shims() {
  local s="$1"
  mkdir -p "$s"
  cat > "$s/wezterm" <<'EOF'
#!/bin/sh
# Модель: пакет wezterm уже стоит (`have wezterm` → install_wezterm_pkg
# ничего не ставит). Вызовов с аргументами шаг Linux не делает.
exit 0
EOF
  cat > "$s/fc-list" <<'EOF'
#!/bin/sh
# Модель fc-list: шрифт CaskaydiaCove уже установлен — install_nerd_font
# ничего не качает (сети в песочнице нет).
echo "/usr/share/fonts/CaskaydiaCoveNerdFont-Regular.ttf: CaskaydiaCove Nerd Font:style=Regular"
EOF
  chmod +x "$s/wezterm" "$s/fc-list"
}

# run <name> [VAR=VALUE ...] — installer from $C, HOME=$H, GUI-сессия.
# Более поздний VAR=VALUE перекрывает ранний (env).
run() {
  local name="$1"; shift
  OUT="$ROOT/$name.out"
  env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" DISPLAY=:0 \
    FORGE_NVIM_SKIP_DEPS=1 FORGE_NVIM_DEPS_ONLY=1 "$@" \
    "$BASH_BIN" "$C/nvim_forge/scripts/install-linux.sh" > "$OUT" 2>&1
  RC=$?
}

fresh() {
  local n="$1"
  C="$ROOT/$n/checkout"; H="$ROOT/$n/home"; SHIMS="$ROOT/shims"
  mkdir -p "$H" "$ROOT/tmp"
  mk_checkout "$C"
  SRC="$(cd -P "$C" && pwd)/wezterm.lua"
}

nbackups() { find "$1" -name "*.backup-*" 2>/dev/null | wc -l | tr -d ' '; }
DST_OF() { printf '%s' "$H/.config/wezterm/wezterm.lua"; }

mk_shims "$ROOT/shims"
printf 'bash under test: %s\n' "$("$BASH_BIN" -c 'echo $BASH_VERSION')"

echo "L1 GUI session, clean HOME"
fresh l1; run l1
check "exit 0" '[ "$RC" -eq 0 ]'
check "link created" '[ -L "$(DST_OF)" ] && [ "$(readlink "$(DST_OF)")" = "$SRC" ]'
check "Linked message" 'grep -q "Linked $(DST_OF) -> $SRC" "$OUT"'

echo "L2 link already there: absolute and relative"
fresh l2; mkdir -p "$H/.config/wezterm"; ln -s "$SRC" "$(DST_OF)"
run l2
check "absolute: already linked, no backups" '[ "$RC" -eq 0 ] && grep -q "WezTerm config already linked: $(DST_OF)" "$OUT" && [ "$(nbackups "$H")" -eq 0 ]'
rm "$(DST_OF)"
rel="$(cd "$H/.config/wezterm" && python3 -c "import os,sys;print(os.path.relpath(sys.argv[1]))" "$SRC")"
ln -s "$rel" "$(DST_OF)"
run l2b
check "relative: already linked, no backups" '[ "$RC" -eq 0 ] && grep -q "WezTerm config already linked" "$OUT" && [ "$(nbackups "$H")" -eq 0 ] && [ "$(readlink "$(DST_OF)")" = "$rel" ]'

echo "L3 foreign file / dangling link at dst -> backup; NO_BACKUP=1 -> exit 1"
fresh l3; mkdir -p "$H/.config/wezterm"; echo 'return {}' > "$(DST_OF)"
run l3
check "foreign file: backed up + linked" '[ "$RC" -eq 0 ] && [ "$(nbackups "$H/.config")" -eq 1 ] && [ "$(readlink "$(DST_OF)")" = "$SRC" ]'
fresh l3b; mkdir -p "$H/.config/wezterm"; ln -s "$H/nope.lua" "$(DST_OF)"
run l3b
check "dangling link: backed up + linked" '[ "$RC" -eq 0 ] && [ "$(nbackups "$H/.config")" -eq 1 ] && [ "$(readlink "$(DST_OF)")" = "$SRC" ]'
fresh l3c; mkdir -p "$H/.config/wezterm"; echo 'return {}' > "$(DST_OF)"
run l3c FORGE_NVIM_NO_BACKUP=1
check "NO_BACKUP: exit 1, file untouched" '[ "$RC" -eq 1 ] && [ -f "$(DST_OF)" ] && [ ! -L "$(DST_OF)" ]'

echo "L4 no GUI session"
fresh l4
OUT="$ROOT/l4.out"
env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" FORGE_NVIM_SKIP_DEPS=1 FORGE_NVIM_DEPS_ONLY=1 \
  "$BASH_BIN" "$C/nvim_forge/scripts/install-linux.sh" > "$OUT" 2>&1; RC=$?
check "exit 0, skipped" '[ "$RC" -eq 0 ] && grep -q "No GUI session detected; skipping WezTerm setup (FORGE_NVIM_FORCE_WEZTERM=1 to force)" "$OUT"'
check "no link" '[ ! -e "$H/.config/wezterm" ]'

echo "L5 overrides are not neutralised (Q13 = A)"
fresh l5; echo 'return {}' > "$H/.wezterm.lua"
run l5 WEZTERM_CONFIG_FILE=/elsewhere.lua
check "exit 0, link created" '[ "$RC" -eq 0 ] && [ -L "$(DST_OF)" ]'
check "~/.wezterm.lua untouched" '[ -f "$H/.wezterm.lua" ] && [ "$(nbackups "$H")" -eq 0 ]'

echo "L6 ~/.config/wezterm is a symlink to the checkout dir"
fresh l6; mkdir -p "$H/.config"; ln -s "$C" "$H/.config/wezterm"
run l6
check "exit 0, already linked" '[ "$RC" -eq 0 ] && grep -q "WezTerm config already linked" "$OUT"'
check "repo file stays a regular file, no backups in checkout" '[ -f "$C/wezterm.lua" ] && [ ! -L "$C/wezterm.lua" ] && [ "$(nbackups "$C")" -eq 0 ]'

echo "L7 ~/.config/wezterm is a dangling symlink"
fresh l7; mkdir -p "$H/.config"; ln -s "$H/gone" "$H/.config/wezterm"
run l7
check "exit 0, repaired" '[ "$RC" -eq 0 ] && [ -d "$H/.config/wezterm" ] && [ ! -L "$H/.config/wezterm" ] && [ -L "$(DST_OF)" ]'
check "dangling dir link backed up" '[ "$(nbackups "$H/.config")" -eq 1 ]'

echo "L8 ~/.config/wezterm -> dotfiles dir with a foreign wezterm.lua"
fresh l8; mkdir -p "$H/dotfiles/wezterm" "$H/.config"; echo 'return {}' > "$H/dotfiles/wezterm/wezterm.lua"
ln -s "$H/dotfiles/wezterm" "$H/.config/wezterm"
run l8
check "dir symlink kept" '[ "$RC" -eq 0 ] && [ -L "$H/.config/wezterm" ]'
check "foreign file backed up inside dotfiles, link there" '[ "$(nbackups "$H/dotfiles/wezterm")" -eq 1 ] && [ "$(readlink "$H/dotfiles/wezterm/wezterm.lua")" = "$SRC" ]'

echo "L9 XDG_CONFIG_HOME inside the checkout is ignored; <checkout>-other is honoured"
fresh l9
( cd "$C" && find . | sort ) > "$ROOT/l9.before"
run l9 XDG_CONFIG_HOME="$C"
check "root: link in ~/.config, nothing new in the repo" '[ "$RC" -eq 0 ] && [ -L "$(DST_OF)" ] && [ "$( cd "$C" && find . | sort )" = "$(cat "$ROOT/l9.before")" ]'
fresh l9b
( cd "$C" && find . | sort ) > "$ROOT/l9b.before"
run l9b XDG_CONFIG_HOME="$C/nvim_forge"
check "subdir: link in ~/.config, nothing new in the repo" '[ "$RC" -eq 0 ] && [ -L "$(DST_OF)" ] && [ "$( cd "$C" && find . | sort )" = "$(cat "$ROOT/l9b.before")" ]'
mkdir -p "$C-other"
run l9c XDG_CONFIG_HOME="$C-other"
check "<checkout>-other honoured" '[ "$RC" -eq 0 ] && [ -L "$C-other/wezterm/wezterm.lua" ]'

echo "L10 curl | bash: no search from the current directory"
fresh l10
OUT="$ROOT/l10.out"
( cd "$C/nvim_forge/scripts" && env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" DISPLAY=:0 \
    FORGE_NVIM_SKIP_DEPS=1 FORGE_NVIM_DEPS_ONLY=1 "$BASH_BIN" < "$C/nvim_forge/scripts/install-linux.sh" > "$OUT" 2>&1 ); RC=$?
check "exit 0" '[ "$RC" -eq 0 ]'
check "skip message, no link" 'grep -q "wezterm.lua not found near the config; skipping terminal config link" "$OUT" && [ ! -e "$(DST_OF)" ]'

echo "L11 the Linux command from the wezterm.lua header works on a clean HOME"
fresh l11
cmd="$(sed -n 's/^--   Linux — \(.*\)$/\1/p' "$C/wezterm.lua" | sed 's/  *(из корня репо)$//' | head -n1)"
check "header has a Linux command" '[ -n "$cmd" ]'
( cd "$C" && env -i HOME="$H" PATH="/usr/bin:/bin" bash -c "$cmd" ) > "$ROOT/l11.out" 2>&1; RC=$?
check "exit 0, link to the repo file" '[ "$RC" -eq 0 ] && [ "$(cd -P "$(dirname "$(readlink "$(DST_OF)")")" && pwd)/wezterm.lua" = "$SRC" ]'
check "header names install-linux.sh" 'grep -q "install-linux.sh" "$C/wezterm.lua"'

printf '\n%d passed, %d failed  (outputs in %s)\n' "$PASS" "$FAIL" "$ROOT"
[ "$FAIL" -eq 0 ]
