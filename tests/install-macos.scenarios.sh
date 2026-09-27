#!/usr/bin/env bash
# Scenario tests for nvim_forge/scripts/install-macos.sh (WezTerm part + mode
# detection + curl bootstrap), run in a sandbox HOME with shims for
# launchctl/wezterm/pgrep. The wezterm shim mimics REAL wezterm 20240203:
# `ls-fonts` on a broken config exits 0 with empty stdout and ERROR on stderr.
# Покрывает openspec/specs/macos-install и openspec/specs/wezterm-config-loading
# (S17–S29 — change fix-macos-installer). Заглушки brew/rustup-init/go — в
# $ROOT/shims; nvim, xcode-select и plutil — отдельными каталогами, в PATH
# только по запросу сценария (Decision 8).
# Нужны: POSIX-окружение с bash, git и python3 (WSL/Linux/macOS).
# usage: tests/install-macos.scenarios.sh [repo-root] [bash-binary]
#   bash-binary — например, собранный bash 3.2.57, как /bin/bash в macOS.
set -u
REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
BASH_BIN="${2:-bash}"
ROOT="$(mktemp -d /tmp/forge-inst-test.XXXXXX)"
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
  cp "$REPO/nvim_forge/scripts/install-macos.sh" "$c/nvim_forge/scripts/install-macos.sh"
  if [ -d "$REPO/nvim_forge/scripts/lib" ]; then cp -R "$REPO/nvim_forge/scripts/lib" "$c/nvim_forge/scripts/lib"; fi
  : > "$c/nvim_forge/init.lua"
}

mk_shims() {
  local s="$1"
  mkdir -p "$s"
  cat > "$s/launchctl" <<'EOF'
#!/bin/sh
store="$FAKE_LAUNCHD"
touch "$store"
case "$1" in
  getenv) grep "^$2=" "$store" | head -n1 | cut -d= -f2- ;;
  unsetenv) grep -v "^$2=" "$store" > "$store.tmp"; mv "$store.tmp" "$store" ;;
  setenv) echo "$2=$3" >> "$store" ;;
esac
exit 0
EOF
  cat > "$s/wezterm" <<'EOF'
#!/bin/sh
# Like real wezterm 20240203: config errors never change the exit code.
if [ "$1" = "--config-file" ] && [ "$3" = "ls-fonts" ]; then
  if [ ! -f "$2" ]; then echo "12:00:00.000  ERROR  wezterm_gui > Error opening $2" >&2; exit 0; fi
  if grep -q FORCE_BROKEN "$2"; then echo "12:00:00.000  ERROR  wezterm_gui > syntax error: boom" >&2; exit 0; fi
  echo "Primary font:"; exit 0
fi
exit 0
EOF
  cat > "$s/pgrep" <<'EOF'
#!/bin/sh
exit "${FAKE_PGREP:-1}"
EOF
  cat > "$s/brew" <<'EOF'
#!/bin/sh
# Модель brew 4.x (fix-macos-installer, Decision 8): `list --formula|--cask
# --versions <имя>` печатает «<имя> <версия>» и код 0, если имя есть в
# FAKE_BREW_INSTALLED (через пробел), иначе пусто и код 1 — так отвечает
# настоящий brew для неустановленного пакета. `install …` пишет вызов в
# журнал FAKE_BREW_LOG. `shellenv` пуст (brew уже в PATH).
case "$1" in
  list) for n in ${FAKE_BREW_INSTALLED:-}; do
          if [ "$n" = "$4" ]; then echo "$4 1.0"; exit 0; fi
        done
        exit 1 ;;
  install) echo "brew $*" >> "$FAKE_BREW_LOG"; exit 0 ;;
esac
exit 0
EOF
  cat > "$s/rustup-init" <<'EOF'
#!/bin/sh
# Модель rustup-init: только журнал вызова (ставить ничего не надо).
echo "rustup-init $*" >> "$FAKE_BREW_LOG"
EOF
  cat > "$s/go" <<'EOF'
#!/bin/sh
# Модель go: `go env GOPATH` — каталог в HOME, как по умолчанию у go;
# `go install …` — только журнал.
case "$1" in
  env) echo "$HOME/go" ;;
  *) echo "go $*" >> "$FAKE_BREW_LOG" ;;
esac
EOF
  chmod +x "$s/launchctl" "$s/wezterm" "$s/pgrep" "$s/brew" "$s/rustup-init" "$s/go"
}

# Заглушки, которые попадают в PATH только по запросу сценария.
mk_optional_shims() {
  mkdir -p "$ROOT/nvimbin" "$ROOT/xcodebin" "$ROOT/plutilbin"
  cat > "$ROOT/nvimbin/nvim" <<'EOF'
#!/bin/sh
# Модель nvim для установщика: пишет в журнал аргументы и окружение, в
# котором его запустили (NVIM_APPNAME, XDG_CONFIG_HOME), — так видно, какой
# конфиг он читал бы. FAKE_NVIM_RC — код возврата на `Lazy! restore`.
echo "nvim $* NVIM_APPNAME=${NVIM_APPNAME:-} XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-}" >> "${FAKE_NVIM_LOG:-$HOME/.nvim.log}"
case "$*" in *"Lazy! restore"*) exit "${FAKE_NVIM_RC:-0}" ;; esac
exit 0
EOF
  cat > "$ROOT/xcodebin/xcode-select" <<'EOF'
#!/bin/sh
# Модель xcode-select -p: путь каталога разработчика и код 0, если CLT
# стоят; без CLT — ошибка (FAKE_XCODE_SELECT_RC ≠ 0). Сам ничего не ставит.
if [ "$1" = "-p" ]; then
  rc="${FAKE_XCODE_SELECT_RC:-0}"
  if [ "$rc" -eq 0 ]; then echo /Library/Developer/CommandLineTools; fi
  exit "$rc"
fi
exit 0
EOF
  cat > "$ROOT/plutilbin/plutil" <<'EOF'
#!/bin/sh
# Модель `plutil -convert xml1 -o - <файл>`: настоящий plutil отдаёт XML с
# тем же содержимым; фикстуры и так XML — печатаем файл как есть. Так в
# песочнице исполняется ветка с plutil; двоичный plist — вручную на Mac.
if [ "$1" = "-convert" ] && [ "$2" = "xml1" ] && [ "$3" = "-o" ] && [ "$4" = "-" ]; then
  cat "$5"; exit $?
fi
exit 1
EOF
  chmod +x "$ROOT/nvimbin/nvim" "$ROOT/xcodebin/xcode-select" "$ROOT/plutilbin/plutil"
}

# run <name> [VAR=VALUE ...]  — runs installer from $C with HOME=$H.
# Более поздний VAR=VALUE перекрывает ранний (env), в том числе PATH.
run() {
  local name="$1"; shift
  OUT="$ROOT/$name.out"
  env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" \
    FAKE_LAUNCHD="$H/.launchd" FAKE_BREW_LOG="$H/.brew.log" FORGE_NVIM_SKIP_DEPS=1 "$@" \
    "$BASH_BIN" "${SCRIPT:-$C/nvim_forge/scripts/install-macos.sh}" > "$OUT" 2>&1
  RC=$?
}

# run_deps <name> [VAR=VALUE ...] — то же, но с шагом зависимостей (без
# FORGE_NVIM_SKIP_DEPS): brew-заглушка, все базовые формулы «установлены».
BASE_FORMULAS="git neovim ripgrep fd cmake tree-sitter-cli"
run_deps() {
  local name="$1"; shift
  OUT="$ROOT/$name.out"
  env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" \
    FAKE_LAUNCHD="$H/.launchd" FAKE_BREW_LOG="$H/.brew.log" FAKE_BREW_INSTALLED="$BASE_FORMULAS" "$@" \
    "$BASH_BIN" "$C/nvim_forge/scripts/install-macos.sh" > "$OUT" 2>&1
  RC=$?
}
NVIM_PATH_OF() { printf '%s' "$ROOT/nvimbin:$SHIMS:/usr/bin:/bin"; }

fresh() {
  local n="$1"
  C="$ROOT/$n/checkout"; H="$ROOT/$n/home"; SHIMS="$ROOT/shims"
  mkdir -p "$H" "$ROOT/tmp"
  mk_checkout "$C"
  SRC="$(cd -P "$C" && pwd)/wezterm.lua"
}

nbackups() { find "$1" -name "*.backup-*" 2>/dev/null | wc -l | tr -d ' '; }
GUARD='# >>> forge-nvim: WezTerm config is the symlink'

mk_shims "$ROOT/shims"
mk_optional_shims
printf 'bash under test: %s\n' "$("$BASH_BIN" -c 'echo $BASH_VERSION')"

echo "S1 fresh HOME, run from monorepo checkout (no flags)"
fresh s1; run s1
check "exit 0" '[ "$RC" -eq 0 ]'
check "link created" '[ -L "$H/.config/wezterm/wezterm.lua" ] && [ "$(readlink "$H/.config/wezterm/wezterm.lua")" = "$SRC" ]'
check "local mode auto (no ~/.config/nvim)" '[ ! -e "$H/.config/nvim" ] && grep -q "untouched" "$OUT"'
check "launch path printed" 'grep -q "Launch: .*/nvim_forge.sh" "$OUT"'
check "effective reported" 'grep -q "WezTerm загрузит: " "$OUT"'
check "load check ran" 'grep -q "загружается без ошибок" "$OUT"'

echo "S2 rerun is a no-op"
run s2
check "exit 0" '[ "$RC" -eq 0 ]'
check "already linked" 'grep -q "already linked" "$OUT"'
check "no backups created" '[ "$(nbackups "$H")" -eq 0 ]'

echo "S3 overrides: ~/.wezterm.lua, zshrc export, symlinked bashrc, launchd env, old file at dst"
fresh s3
echo 'return {}' > "$H/.wezterm.lua"
printf 'alias ll=ls\nexport WEZTERM_CONFIG_FILE="$HOME/old/wezterm.lua"\n# WEZTERM_CONFIG_FILE=commented\necho keep\n' > "$H/.zshrc"
cp "$H/.zshrc" "$ROOT/s3.zshrc.orig"
mkdir -p "$H/dotfiles"
printf 'WEZTERM_CONFIG_FILE=/x/y.lua\nexport PATH=$PATH\n' > "$H/dotfiles/bashrc"
ln -s "$H/dotfiles/bashrc" "$H/.bashrc"
printf '# only a comment: WEZTERM_CONFIG_FILE\n' > "$H/.profile"
mkdir -p "$H/.config/wezterm"; echo 'return { old = true }' > "$H/.config/wezterm/wezterm.lua"
echo "WEZTERM_CONFIG_FILE=/elsewhere.lua" > "$H/.launchd"
run s3 FAKE_PGREP=0
check "exit 0" '[ "$RC" -eq 0 ]'
check "~/.wezterm.lua moved to backup" '[ ! -e "$H/.wezterm.lua" ] && ls "$H"/.wezterm.lua.backup-* >/dev/null 2>&1'
check "zshrc original lines untouched" '[ "$(head -n 4 "$H/.zshrc")" = "$(cat "$ROOT/s3.zshrc.orig")" ]'
check "zshrc guard appended" 'grep -qF "$GUARD" "$H/.zshrc" && tail -n 2 "$H/.zshrc" | grep -qx "unset WEZTERM_CONFIG_FILE"'
check "zshrc: var really unset after sourcing" '[ -z "$(HOME="$H" bash -c ". \"$H/.zshrc\" >/dev/null; printf %s \"\${WEZTERM_CONFIG_FILE:-}\"")" ]'
check "bashrc still a symlink" '[ -L "$H/.bashrc" ]'
check "bashrc target got guard" 'grep -qF "$GUARD" "$H/dotfiles/bashrc" && grep -q "^WEZTERM_CONFIG_FILE=/x/y.lua" "$H/dotfiles/bashrc"'
check "comment-only profile untouched" '! grep -qF "$GUARD" "$H/.profile"'
check "launchd var removed" '! grep -q WEZTERM_CONFIG_FILE "$H/.launchd"'
check "old dst backed up + linked" '[ -L "$H/.config/wezterm/wezterm.lua" ] && ls "$H"/.config/wezterm/wezterm.lua.backup-* >/dev/null 2>&1'
check "restart hint" 'grep -q "Cmd+Q" "$OUT"'
run s3b
check "rerun: exit 0" '[ "$RC" -eq 0 ]'
check "rerun: guard not duplicated" '[ "$(grep -cF "$GUARD" "$H/.zshrc")" -eq 1 ]'
check "rerun: no restart hint" '! grep -q "Cmd+Q" "$OUT"'

echo "S4 run from a nvim_forge terminal (XDG_CONFIG_HOME = repo root)"
fresh s4
run s4 XDG_CONFIG_HOME="$C"
check "exit 0" '[ "$RC" -eq 0 ]'
check "gui link (~/.config)" '[ -L "$H/.config/wezterm/wezterm.lua" ]'
check "no stray link inside repo" '[ ! -e "$C/wezterm/wezterm.lua" ]'

echo "S5 launchd XDG_CONFIG_HOME set"
fresh s5
echo "XDG_CONFIG_HOME=$H/guixdg" > "$H/.launchd"
run s5
check "exit 0" '[ "$RC" -eq 0 ]'
check "link at launchd XDG" '[ -L "$H/guixdg/wezterm/wezterm.lua" ]'
check "effective is launchd XDG" 'grep -q "WezTerm загрузит: $H/guixdg/wezterm/wezterm.lua" "$OUT"'

echo "S6 broken wezterm.lua (real-wezterm behaviour: exit 0 + ERROR) -> exit 1"
fresh s6
echo '-- FORCE_BROKEN' >> "$C/wezterm.lua"
run s6
check "exit 1" '[ "$RC" -eq 1 ]'
check "error shown" 'grep -q "не загружается" "$OUT" && grep -q "syntax error: boom" "$OUT"'

echo "S7 curl | bash: bootstraps a checkout and continues from it"
fresh s7
( cd "$C" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && git branch -M main ) >/dev/null 2>&1
( cd "$H" && env -i HOME="$H" PATH="$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" FAKE_LAUNCHD="$H/.launchd" \
    FORGE_NVIM_SKIP_DEPS=1 FORGE_NVIM_REPO="$C" FORGE_NVIM_SRC="$H/forge-nvim" \
    "$BASH_BIN" < "$C/nvim_forge/scripts/install-macos.sh" > "$ROOT/s7.out" 2>&1 ); RC=$?; OUT="$ROOT/s7.out"
check "exit 0" '[ "$RC" -eq 0 ]'
check "checkout cloned" '[ -f "$H/forge-nvim/nvim_forge.sh" ]'
check "linked to the clone" '[ "$(readlink "$H/.config/wezterm/wezterm.lua")" = "$(cd -P "$H/forge-nvim" && pwd)/wezterm.lua" ]'
check "local mode after re-exec" 'grep -q "Launch: .*forge-nvim/nvim_forge.sh" "$OUT"'

echo "S8 NO_BACKUP=1 with ~/.wezterm.lua + launchd override -> refuse before touching env"
fresh s8
echo 'return {}' > "$H/.wezterm.lua"
echo "WEZTERM_CONFIG_FILE=/elsewhere.lua" > "$H/.launchd"
printf 'export WEZTERM_CONFIG_FILE=/x.lua\n' > "$H/.zshrc"
run s8 FORGE_NVIM_NO_BACKUP=1
check "non-zero exit" '[ "$RC" -ne 0 ]'
check "file untouched" '[ -f "$H/.wezterm.lua" ]'
check "launchd untouched" 'grep -q WEZTERM_CONFIG_FILE "$H/.launchd"'
check "profile untouched" '! grep -qF "$GUARD" "$H/.zshrc"'

echo "S9 dangling symlink at dst + relative correct link"
fresh s9
mkdir -p "$H/.config/wezterm"; ln -s "$H/nope.lua" "$H/.config/wezterm/wezterm.lua"
run s9
check "exit 0" '[ "$RC" -eq 0 ]'
check "relinked to src" '[ "$(readlink "$H/.config/wezterm/wezterm.lua")" = "$SRC" ]'
rm "$H/.config/wezterm/wezterm.lua"
rel="$(cd "$H/.config/wezterm" && python3 -c "import os,sys;print(os.path.relpath(sys.argv[1]))" "$SRC")"
ln -s "$rel" "$H/.config/wezterm/wezterm.lua"
nb="$(nbackups "$H/.config")"
run s9b
check "relative link accepted" 'grep -q "already linked" "$OUT" && [ "$(nbackups "$H/.config")" -eq "$nb" ]'

echo "S10 ~/.wezterm.lua already a link to repo file -> kept"
fresh s10
ln -s "$SRC" "$H/.wezterm.lua"
run s10
check "exit 0" '[ "$RC" -eq 0 ]'
check "kept" '[ -L "$H/.wezterm.lua" ] && [ "$(nbackups "$H")" -eq 0 ]'
check "effective = ~/.wezterm.lua -> src" 'grep -q "WezTerm загрузит: $H/.wezterm.lua -> $SRC" "$OUT"'

echo "S11 explicit FORGE_NVIM_DEPS_ONLY=0 + USE_LOCAL_SOURCE=1 from checkout -> symlink, nothing copied"
fresh s11
run s11 FORGE_NVIM_DEPS_ONLY=0 FORGE_NVIM_USE_LOCAL_SOURCE=1 FORGE_NVIM_INSTALL_DIR="$H/.config/nvim" PATH="$(NVIM_PATH_OF)"
CFG="$(cd -P "$C" && pwd)/nvim_forge"
check "exit 0" '[ "$RC" -eq 0 ]'
check "symlink to <checkout>/nvim_forge" '[ -L "$H/.config/nvim" ] && [ "$(readlink "$H/.config/nvim")" = "$CFG" ]'
check "Linked message" 'grep -q "Linked $H/.config/nvim -> $CFG" "$OUT"'
check "nvim_forge stays a plain dir" '[ -d "$C/nvim_forge" ] && [ ! -L "$C/nvim_forge" ]'

echo "S12 profile edge cases stay syntactically valid (nothing is rewritten)"
fresh s12
cat > "$H/.zshrc" <<'EOF'
if [ -d "$HOME/repo" ]; then
    export WEZTERM_CONFIG_FILE="$HOME/repo/wezterm.lua"; fi
export WEZTERM_CONFIG_FILE=\
  "/cont/path.lua"
export FOO=1 WEZTERM_CONFIG_FILE=/multi.lua; export EDITOR=nvim
EOF
printf 'echo last' >> "$H/.zshrc"
cp "$H/.zshrc" "$ROOT/s12.orig"
run s12
check "exit 0" '[ "$RC" -eq 0 ]'
check "original content is an untouched prefix" '[ "$(head -c "$(wc -c < "$ROOT/s12.orig")" "$H/.zshrc")" = "$(cat "$ROOT/s12.orig")" ]'
check "profile still parses (bash -n)" 'bash -n "$H/.zshrc"'
check "EDITOR still set after sourcing, var unset" '[ "$(HOME="$H" bash -c ". \"$H/.zshrc\" >/dev/null; printf %s \"\$EDITOR:\${WEZTERM_CONFIG_FILE:-}\"")" = "nvim:" ]'
if command -v zsh >/dev/null 2>&1; then check "profile parses (zsh -n)" 'zsh -n "$H/.zshrc"'; fi

# mkplist <файл> <аргумент…> — LaunchAgent, который при входе выполняет
# команду из ProgramArguments (так выглядит настоящий plist setenv-агента).
mkplist() {
  local f="$1" a; shift
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n'
    printf '  <key>Label</key>\n  <string>test.env</string>\n  <key>ProgramArguments</key>\n  <array>\n'
    for a in "$@"; do printf '    <string>%s</string>\n' "$a"; done
    printf '  </array>\n  <key>RunAtLoad</key>\n  <true/>\n</dict>\n</plist>\n'
  } > "$f"
}

echo "S13 LaunchAgent re-sets WEZTERM_CONFIG_FILE at login"
fresh s13
mkdir -p "$H/Library/LaunchAgents"
mkplist "$H/Library/LaunchAgents/env.plist" launchctl setenv WEZTERM_CONFIG_FILE /elsewhere.lua
run s13
check "exit 1" '[ "$RC" -eq 1 ]'
check "plist named" 'grep -q "env.plist выставляет WEZTERM_CONFIG_FILE" "$OUT"'
mkplist "$H/Library/LaunchAgents/env.plist" /bin/launchctl setenv WEZTERM_CONFIG_FILE "$SRC"
run s13b
check "plist pointing to repo -> exit 0" '[ "$RC" -eq 0 ]'

echo "S14 ~/.config/wezterm is a directory symlink to the checkout"
fresh s14
mkdir -p "$H/.config"; ln -s "$C" "$H/.config/wezterm"
run s14
check "exit 0" '[ "$RC" -eq 0 ]'
check "repo file intact (regular file)" '[ -f "$C/wezterm.lua" ] && [ ! -L "$C/wezterm.lua" ]'
check "no backup of the repo file" '[ "$(nbackups "$C")" -eq 0 ]'

echo "S15 dangling directory symlink ~/.config/wezterm"
fresh s15
mkdir -p "$H/.config"; ln -s "$H/gone" "$H/.config/wezterm"
run s15
check "exit 0" '[ "$RC" -eq 0 ]'
check "repaired" '[ -d "$H/.config/wezterm" ] && [ -L "$H/.config/wezterm/wezterm.lua" ]'

echo "S16 read-only profile"
fresh s16
printf 'export WEZTERM_CONFIG_FILE=/x.lua\n' > "$H/.zshrc"; chmod 444 "$H/.zshrc"
run s16
check "exit 0 (Dock path is fine)" '[ "$RC" -eq 0 ]'
check "warned with the command to add" 'grep -q "недоступен для записи" "$OUT"'
check "no temp leftovers" '[ -z "$(ls "$ROOT/tmp" 2>/dev/null)" ]'
chmod 644 "$H/.zshrc"

echo "S17 Nerd Font already in ~/Library/Fonts (cask not installed), then no font files"
fresh s17
mkdir -p "$H/Library/Fonts"; : > "$H/Library/Fonts/CaskaydiaCoveNerdFont-Regular.ttf"
run_deps s17
check "exit 0" '[ "$RC" -eq 0 ]'
check "font present: cask not called" '! grep -q "install --cask font-caskaydia-cove-nerd-font" "$H/.brew.log" 2>/dev/null'
check "already present message" 'grep -q "already present in Library/Fonts" "$OUT"'
rm -f "$H/Library/Fonts/CaskaydiaCoveNerdFont-Regular.ttf"
run_deps s17b
check "no font files: cask called exactly once" '[ "$(grep -c "install --cask font-caskaydia-cove-nerd-font" "$H/.brew.log")" -eq 1 ]'

echo "S18 WITH_LANGUAGES=1, ~/.cargo/bin/cargo exists but ~/.cargo/bin not in PATH"
fresh s18
mkdir -p "$H/.cargo/bin"; printf '#!/bin/sh\nexit 0\n' > "$H/.cargo/bin/cargo"; chmod +x "$H/.cargo/bin/cargo"
run_deps s18 FORGE_NVIM_WITH_LANGUAGES=1 FAKE_BREW_INSTALLED="$BASE_FORMULAS go python rustup-init"
check "exit 0" '[ "$RC" -eq 0 ]'
check "rustup-init not called" '! grep -q "rustup-init" "$H/.brew.log" 2>/dev/null'
check "rust hint printed" 'grep -qF "rust: already installed (~/.cargo/bin; добавь этот каталог в PATH, если его там нет)" "$OUT"'

echo "S19 curl | bash on a mac without Xcode CLT (/usr/bin/git is the stub)"
fresh s19
( cd "$C" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && git branch -M main ) >/dev/null 2>&1
( cd "$H" && env -i HOME="$H" PATH="$ROOT/xcodebin:$SHIMS:/usr/bin:/bin" TMPDIR="$ROOT/tmp" FAKE_LAUNCHD="$H/.launchd" \
    FAKE_XCODE_SELECT_RC=2 FORGE_NVIM_SKIP_DEPS=1 FORGE_NVIM_REPO="$C" FORGE_NVIM_SRC="$H/forge-nvim" \
    "$BASH_BIN" < "$C/nvim_forge/scripts/install-macos.sh" > "$ROOT/s19.out" 2>&1 ); RC=$?; OUT="$ROOT/s19.out"
check "exit 1" '[ "$RC" -eq 1 ]'
check "xcode-select hint" 'grep -qF "git is required: run \`xcode-select --install\`, then rerun this command." "$OUT"'
check "nothing cloned" '[ ! -e "$H/forge-nvim" ]'

echo "S20 profile: new assignment after the forge-nvim block"
fresh s20
printf 'export WEZTERM_CONFIG_FILE=/a.lua\n\n%s\nunset WEZTERM_CONFIG_FILE\n# <<< forge-nvim <<<\nexport WEZTERM_CONFIG_FILE=/x.lua\n' \
  "# >>> forge-nvim: WezTerm config is the symlink ~/.config/wezterm/wezterm.lua (install-macos.sh) >>>" > "$H/.zshrc"
cp "$H/.zshrc" "$ROOT/s20.orig"
run s20
check "exit 0" '[ "$RC" -eq 0 ]'
check "second block appended" '[ "$(grep -cF "$GUARD" "$H/.zshrc")" -eq 2 ]'
check "original lines are an untouched prefix" '[ "$(head -c "$(wc -c < "$ROOT/s20.orig")" "$H/.zshrc")" = "$(cat "$ROOT/s20.orig")" ]'
check "var unset after sourcing" '[ -z "$(HOME="$H" bash -c ". \"$H/.zshrc\" >/dev/null; printf %s \"\${WEZTERM_CONFIG_FILE:-}\"")" ]'
cp "$H/.zshrc" "$ROOT/s20.after2"
run s20b
check "third run: file unchanged" 'cmp -s "$H/.zshrc" "$ROOT/s20.after2"'

echo "S21 LaunchAgent variants (with and without plutil)"
for with_plutil in 0 1; do
  fresh "s21-$with_plutil"
  if [ "$with_plutil" = 1 ]; then P="$ROOT/plutilbin:$SHIMS:/usr/bin:/bin"; else P="$SHIMS:/usr/bin:/bin"; fi
  LA="$H/Library/LaunchAgents"; mkdir -p "$LA"
  mkplist "$LA/a.plist" launchctl unsetenv WEZTERM_CONFIG_FILE
  run "s21-$with_plutil-unset" PATH="$P"
  check "plutil=$with_plutil: only unsetenv -> exit 0" '[ "$RC" -eq 0 ]'
  rm -f "$LA"/*.plist
  printf '<plist><dict><key>Label</key><string>x</string><key>EnvironmentVariables</key><dict><key>WEZTERM_CONFIG_FILE</key><string>/elsewhere.lua</string></dict><key>ProgramArguments</key><array><string>/usr/bin/true</string></array></dict></plist>\n' > "$LA/b.plist"
  run "s21-$with_plutil-envvars" PATH="$P"
  check "plutil=$with_plutil: EnvironmentVariables only -> exit 0" '[ "$RC" -eq 0 ]'
  rm -f "$LA"/*.plist
  rel="${SRC#"$(dirname -- "$(cd -P "$H" && pwd)")"/}"
  mkplist "$LA/c.plist" /bin/sh -c "launchctl setenv WEZTERM_CONFIG_FILE ~/../$rel"
  run "s21-$with_plutil-tilde" PATH="$P"
  check "plutil=$with_plutil: sh -c with ~/<repo path> -> exit 0" '[ "$RC" -eq 0 ]'
  rm -f "$LA"/*.plist
  ln -sf "$SRC" "$H/alias.lua"
  mkplist "$LA/d.plist" launchctl setenv WEZTERM_CONFIG_FILE "$H/alias.lua"
  run "s21-$with_plutil-symlink" PATH="$P"
  check "plutil=$with_plutil: repo path via symlink -> exit 0" '[ "$RC" -eq 0 ]'
  rm -f "$LA"/*.plist
  mkplist "$LA/e.plist" /bin/sh -c "echo hi; launchctl setenv WEZTERM_CONFIG_FILE /elsewhere.lua; true"
  run "s21-$with_plutil-shell" PATH="$P"
  check "plutil=$with_plutil: sh -c with foreign path -> exit 1, named" '[ "$RC" -eq 1 ] && grep -q "e.plist выставляет" "$OUT"'
  rm -f "$LA"/*.plist
  mkplist "$LA/f1.plist" launchctl setenv WEZTERM_CONFIG_FILE /one.lua
  mkplist "$LA/f2.plist" launchctl setenv WEZTERM_CONFIG_FILE /two.lua
  run "s21-$with_plutil-two" PATH="$P"
  check "plutil=$with_plutil: two plists -> both named" '[ "$RC" -eq 1 ] && grep -q "f1.plist выставляет" "$OUT" && grep -q "f2.plist выставляет" "$OUT"'
done

echo "S22 restart hint from a WezTerm pane"
fresh s22
ln -s "$SRC" "$H/.wezterm.lua"
run s22a FAKE_PGREP=0 WEZTERM_PANE=1 WEZTERM_CONFIG_DIR="$H"
check "pane loaded ~/.wezterm.lua -> repo: no hint" '[ "$RC" -eq 0 ] && ! grep -q "Cmd+Q" "$OUT"'
fresh s22b
run s22b0
ln -s "$SRC" "$H/other-name.lua"
run s22b FAKE_PGREP=0 WEZTERM_PANE=1 WEZTERM_CONFIG_DIR="$H" WEZTERM_CONFIG_FILE="$H/other-name.lua"
check "pane WEZTERM_CONFIG_FILE -> repo under another name: no hint" '[ "$RC" -eq 0 ] && ! grep -q "Cmd+Q" "$OUT"'
run s22c FAKE_PGREP=0 WEZTERM_PANE=1 WEZTERM_CONFIG_DIR="$H" WEZTERM_CONFIG_FILE="/elsewhere.lua"
check "pane WEZTERM_CONFIG_FILE not in repo: hint" '[ "$RC" -eq 0 ] && grep -q "Cmd+Q" "$OUT"'

echo "S23 install into ~/.config/nvim: symlink, restore, rerun"
fresh s23
CFG="$(cd -P "$C" && pwd)/nvim_forge"
run s23 FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)"
check "exit 0" '[ "$RC" -eq 0 ]'
check "~/.config/nvim -> <checkout>/nvim_forge" '[ -L "$H/.config/nvim" ] && [ "$(readlink "$H/.config/nvim")" = "$CFG" ]'
check "installed message" 'grep -q "forge-nvim installed: $H/.config/nvim" "$OUT" && grep -q "Start with: nvim" "$OUT"'
check "Lazy! restore for the installed config" 'grep -q "Lazy! restore.*NVIM_APPNAME=nvim XDG_CONFIG_HOME=$H/.config" "$H/.nvim.log"'
check "no Lazy! sync" '! grep -q "Lazy! sync" "$H/.nvim.log"'
run s23b FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)"
check "rerun: already linked" '[ "$RC" -eq 0 ] && grep -q "forge-nvim config already linked: $H/.config/nvim" "$OUT"'
check "rerun: no backups" '[ "$(nbackups "$H")" -eq 0 ]'
run s23c FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)" FAKE_NVIM_RC=1
check "restore failure -> non-zero exit" '[ "$RC" -ne 0 ]'

echo "S24 occupied install path: dir, file, dangling link, link to another checkout; NO_BACKUP"
for kind in dir file dangling other; do
  fresh "s24-$kind"
  CFG="$(cd -P "$C" && pwd)/nvim_forge"
  mkdir -p "$H/.config"
  case "$kind" in
    dir) mkdir -p "$H/.config/nvim"; echo mine > "$H/.config/nvim/init.lua" ;;
    file) echo file > "$H/.config/nvim" ;;
    dangling) ln -s "$H/gone" "$H/.config/nvim" ;;
    other) mk_checkout "$ROOT/s24-$kind/other"; ln -s "$ROOT/s24-$kind/other/nvim_forge" "$H/.config/nvim" ;;
  esac
  run "s24-$kind" FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)"
  check "$kind: exit 0, backed up, relinked" '[ "$RC" -eq 0 ] && [ "$(nbackups "$H/.config")" -eq 1 ] && [ "$(readlink "$H/.config/nvim")" = "$CFG" ]'
  if [ "$kind" = other ]; then
    check "other: target of the old link untouched" '[ -f "$ROOT/s24-other/other/nvim_forge/init.lua" ]'
  fi
done
fresh s24-nobackup
mkdir -p "$H/.config/nvim"; echo mine > "$H/.config/nvim/init.lua"
run s24-nobackup FORGE_NVIM_DEPS_ONLY=0 FORGE_NVIM_NO_BACKUP=1 PATH="$(NVIM_PATH_OF)"
check "NO_BACKUP: exit 1, message, path untouched" '[ "$RC" -eq 1 ] && grep -q "Install path already exists: $H/.config/nvim" "$OUT" && [ -f "$H/.config/nvim/init.lua" ] && [ ! -L "$H/.config/nvim" ]'

echo "S25 refusals happen before any backup"
fresh s25a
mkdir -p "$H/.config/nvim"; echo mine > "$H/.config/nvim/init.lua"
run s25a FORGE_NVIM_DEPS_ONLY=0
check "no nvim: exit 1, message, nothing touched" '[ "$RC" -eq 1 ] && grep -q "nvim is not available in PATH" "$OUT" && [ "$(nbackups "$H")" -eq 0 ] && [ ! -e "$H/.config/wezterm" ]'
fresh s25b
rm -f "$C/nvim_forge/init.lua"
run s25b FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)"
check "no nvim_forge/init.lua: exit 1, message" '[ "$RC" -eq 1 ] && grep -q "No init.lua in .*nvim_forge: this is not a Neovim config." "$OUT" && [ ! -e "$H/.config/wezterm" ]'
for where in same parent inside; do
  fresh "s25-$where"
  case "$where" in
    same) dst="$C" ;;
    parent) dst="$(dirname -- "$C")" ;;
    inside) dst="$C/sub/nvim" ;;
  esac
  run "s25-$where" FORGE_NVIM_DEPS_ONLY=0 FORGE_NVIM_INSTALL_DIR="$dst" PATH="$(NVIM_PATH_OF)"
  check "overlap ($where): exit 1, message, nothing touched" '[ "$RC" -eq 1 ] && grep -q "overlaps the forge-nvim checkout" "$OUT" && [ "$(nbackups "$ROOT/s25-$where")" -eq 0 ] && [ ! -e "$H/.config/wezterm" ] && [ ! -e "$C/sub" ]'
done

echo "S26 run from a nvim_forge terminal (XDG_CONFIG_HOME = repo, NVIM_APPNAME=nvim_forge)"
fresh s26
( cd "$C" && find . | sort ) > "$ROOT/s26.before"
run s26 FORGE_NVIM_DEPS_ONLY=0 XDG_CONFIG_HOME="$C" NVIM_APPNAME=nvim_forge PATH="$(NVIM_PATH_OF)"
check "exit 0" '[ "$RC" -eq 0 ]'
check "install path is ~/.config/nvim" '[ -L "$H/.config/nvim" ]'
check "nothing new inside the repo" '[ "$( cd "$C" && find . | sort )" = "$(cat "$ROOT/s26.before")" ]'
check "nvim ran for the installed config" 'grep -q "Lazy! restore.*NVIM_APPNAME=nvim XDG_CONFIG_HOME=$H/.config" "$H/.nvim.log"'
mkdir -p "$C-other"
run s26b FORGE_NVIM_DEPS_ONLY=0 XDG_CONFIG_HOME="$C-other" PATH="$(NVIM_PATH_OF)"
check "sibling <checkout>-other is honoured" '[ "$RC" -eq 0 ] && [ -L "$C-other/nvim" ]'

echo "S27 script file outside a checkout in install mode -> bootstrap, keep the mode"
fresh s27
( cd "$C" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && git branch -M main ) >/dev/null 2>&1
mkdir -p "$ROOT/s27/dl"; cp "$C/nvim_forge/scripts/install-macos.sh" "$ROOT/s27/dl/install-macos.sh"
SCRIPT="$ROOT/s27/dl/install-macos.sh" run s27 FORGE_NVIM_REPO="$C" FORGE_NVIM_SRC="$H/forge-nvim" PATH="$(NVIM_PATH_OF)"
CLONE="$(cd -P "$H/forge-nvim" 2>/dev/null && pwd)"
check "exit 0, cloned" '[ "$RC" -eq 0 ] && [ -f "$H/forge-nvim/nvim_forge.sh" ]'
check "~/.config/nvim -> clone/nvim_forge" '[ "$(readlink "$H/.config/nvim")" = "$CLONE/nvim_forge" ]'
check "wezterm link -> clone" '[ "$(readlink "$H/.config/wezterm/wezterm.lua")" = "$CLONE/wezterm.lua" ]'
fresh s27b
SCRIPT="$ROOT/s27/dl/install-macos.sh" run s27b FORGE_NVIM_USE_LOCAL_SOURCE=1 FORGE_NVIM_REPO="$C" FORGE_NVIM_SRC="$H/forge-nvim" PATH="$(NVIM_PATH_OF)"
check "USE_LOCAL_SOURCE outside checkout: refuse before anything" '[ "$RC" -eq 1 ] && grep -q "FORGE_NVIM_USE_LOCAL_SOURCE=1 requested, but script is not running from a forge-nvim checkout." "$OUT" && [ ! -e "$H/forge-nvim" ] && [ ! -e "$H/.config" ]'
fresh s27c
mkdir -p "$H/.config/nvim"; echo mine > "$H/.config/nvim/init.lua"
SCRIPT="$ROOT/s27/dl/install-macos.sh" run s27c FORGE_NVIM_REPO="$C" FORGE_NVIM_SRC="$H/forge-nvim" FAKE_XCODE_SELECT_RC=1 PATH="$ROOT/xcodebin:$(NVIM_PATH_OF)"
check "no git (CLT stub): bootstrap refuses, install path untouched" '[ "$RC" -eq 1 ] && grep -q "xcode-select --install" "$OUT" && [ -f "$H/.config/nvim/init.lua" ] && [ "$(nbackups "$H")" -eq 0 ]'

echo "S28 ~/.config/nvim is a git clone of the monorepo -> backed up, not fetched"
fresh s28
( cd "$C" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && git branch -M main ) >/dev/null 2>&1
mkdir -p "$H/.config"; git clone -q "$C" "$H/.config/nvim" >/dev/null 2>&1
head_before="$(git -C "$H/.config/nvim" rev-parse HEAD)"
run s28 FORGE_NVIM_DEPS_ONLY=0 PATH="$(NVIM_PATH_OF)"
bk="$(ls -d "$H"/.config/nvim.backup-* 2>/dev/null | head -n1)"
check "exit 0, clone in backup, symlink in place" '[ "$RC" -eq 0 ] && [ -n "$bk" ] && [ -L "$H/.config/nvim" ]'
check "backup HEAD unchanged, no fetch" '[ "$(git -C "$bk" rev-parse HEAD)" = "$head_before" ] && [ ! -e "$bk/.git/FETCH_HEAD" ]'

echo "S29 the header names every FORGE_NVIM_* variable the script reads"
INST="$REPO/nvim_forge/scripts/install-macos.sh"
hdr="$(sed -n '1,/^set -euo pipefail/p' "$INST")"
missing=""
for v in $(sed -n '/^set -euo pipefail/,$p' "$INST" | grep -o 'FORGE_NVIM_[A-Z_]*' | sort -u); do
  printf '%s' "$hdr" | grep -q "$v" || missing="$missing $v"
done
check "every flag documented in the header (missing:${missing:- none})" '[ -z "$missing" ]'
check "brew shellenv profile documented (bash_profile)" 'printf "%s" "$hdr" | grep -q "bash_profile"'

printf '\n%d passed, %d failed  (outputs in %s)\n' "$PASS" "$FAIL" "$ROOT"
[ "$FAIL" -eq 0 ]
