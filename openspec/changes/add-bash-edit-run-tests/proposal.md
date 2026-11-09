# Proposal

## Why

Следующий пункт roadmap после §115 — Bash/SQL. IDE-056: в baseline 4b859b8
есть Bash Treesitter catalog, но нет shell LSP/formatter, запуска файла в
Tasks и Bash Tests. Нужны ADDED IDE-SH-1/2/3/4 и реальные пользовательские E2E,
а не подмена языкового покрытия тестами наших install scripts.

## What Changes

- Bash Language Server через Node + JS entrypoint, navigation/completion/
  diagnostics и доступные server refactors; shfmt manual/on-save.
- Явный BashRunFile/Space j b с native argv/cwd, stdout/stderr/status в общих
  Tasks; в Windows Git Bash/явный native Bash, без выбора WSL launcher.
- Bats nearest/file/pass/fail/output через публичный Neotest adapter
  interface, без добавления нового plugin и shell string; настоящий exit/TAP
  подтверждает выбранный test, output сохраняется в результате.
- Общая конфигурация Windows/macOS/Ubuntu, системные различия только на
  границе executable/path. Установка SDK/tools остаётся явной, startup пассивный.
- Pinned test tools/parser/npm lock, private Unicode/space fixture, source RED
  на baseline, Windows/Ubuntu регресс и append история/команды/матрица/roadmap.

Bash DAP остаётся частью общего roadmap и отдельным следующим change:
upstream bash-debug 0.3.9 на Windows жёстко использует WSL, Git Bash не является
его штатным backend. Выбор отдельного Linux backend задан владельцу параллельно;
этот change не объявляет F5/debug nearest реализованными и не закрывает весь Bash.

## Capabilities

### New Capabilities

- `bash-workflow`: IDE-SH-1/2/3/4 — язык, форматирование, запуск и обычные тесты.

### Modified Capabilities

Нет. Общие панели/hotkeys и семантика остальных языков сохраняются.

## Impact

Новый forge.bash, существующие LSP/format/tasks/tests registrations, common
node tool resolver; 67 plugin pins сохраняются. Явные test-deps и Ubuntu image,
E2E registry/docs/FIXLOG. Windows — native Git Bash 5.2.37; POSIX — host Bash,
обычный workflow допускает Bash 3.x. Mac/GUI/Bash DAP без запуска не PASS.
