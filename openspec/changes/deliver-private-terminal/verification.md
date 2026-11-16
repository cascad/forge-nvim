# Verification

2026-11-16. IDE-BOOT-28; WT-LOAD-1 и WT-STATE-4 delta, baseline не менялся.

## Native Windows

Первый targeted run: cases01–04 PASS; case05 настоящий GUI/editor/input/save/quit
прошёл, но foreign-profile oracle поймал NVIDIA/GLCache, созданный GPU driver.
В GUI fixture USERPROFILE направлен в отдельный disposable GUI profile на F,
WEZTERM_CONFIG_FILE указывает на guarded foreign config: explicit kit config
должен его перекрывать. Production environment не менялся.
Адресный case05 PASS28.273s (e2e-windows-v2.txt). Полный suite не повторялся.

Прежние tests/wezterm/window-state.test.lua:60 PASS. Native WezTerm20240203
из pinned official zip, private fonts, реальный GUI/ConPTY и Neovim0.12.2.
Native input/quit адресованы полученной pane/socket конкретного экземпляра.
Cleanup проверяет точный path собственного GUI, name-wide kill отсутствует.

## Native Ubuntu

Первый run cases02–04 PASS, GUI05 skip, font01 fail: console image без GUI libs.
Адресный01 v2 показал следующую missing transitive library. Prepared test inputs
расширены до12 пакетов из official noble/main с SHA из Packages.xz; dpkg-deb -x
только в guest /tmp, без host install/image build/pull/Desktop/WSL изменений.
ldd preflight проверяет полный набор перед E2E. Адресный01 v3 PASS21.537s.
Native GUI Ubuntu в этом окружении не проверялся.

## Installed readiness

После первых consumer checks в installer добавлен native config/font gate до
publish staging, поскольку --version не проверяет GUI dependencies/config/font.
ls-fonts требует private path/face; exit0 с defaults не принимается, timeout20s.
Добавлен case06: hash-valid catalog/component с invalid TTF обязан сохранить
runtime/config/bin/ready прежнего kit. Целевой повтор только01+06 на обеих ОС;
Windows2 PASS63.226s, Ubuntu2 PASS53.977s. Raw font-gate-windows.txt/
font-gate-ubuntu.txt. После них только limit20s вместо общего10min, ясные publisher
errors/защита output overlap и документация; зелёные suites не повторяются.

## Boundaries

Preparation/package перепроверяет official archives, exact payload и native
version; проверены modified binary/license/source. Source/license/SHA metadata
в component. Другие Core plugins/setup здесь fixtures; full Default не заявлен.
Mac descriptor universal .app записан, native acceptance не выполнялся.
Linux x64 AppImage extracted usr/bin сохраняет native RPATH; обычные Desktop
GUI dependencies нужны, на чистом server их молча не устанавливаем.
Window state/config/font принадлежат kit. Native WezTerm per-PID IPC/log и GPU
driver caches используют штатные OS locations; HOME/SDK homes не подменяются.
Production catalog пуст; sync/archive/push отсутствуют.

Raw evidence: .tests/terminal-runtime, exported .tests/ubuntu/install-isolation.
Frozen25/raw journal prefixes сохранены, AST/Lua/Bash/PowerShell parse и strict
OpenSpec прошли. Own Windows stand payloads5040099820 bytes удалены с сохранением
receipts/raw evidence и ready Terminal archive; obsolete preparation заменена
актуальной в default Windows path. Cleanup metadata: .tests/terminal-runtime/cleanup.json.
Exact allowlist25/staged journal prefixes проверяются перед local commit;
чужой E2E/catalog WIP не включается.
