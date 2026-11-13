# Proposal

## Why

IDE-057/очередь5: Bash имеет язык/run/tests, но F5 не даёт обычный debug workflow.
Владелец выбрал WSL2 как Windows backend; native Ubuntu уже запущен и готов.

## What Changes

- Официальный bash-debug/bashdb: Windows Node adapter со штатным WSL launcher,
  Linux/macOS native Bash4+. Собственный debug backend/WSL bridge не добавляется.
- F5 текущего sh-файла без launch.json и type=bashdb из launch.json; обычные
  панели/Output/breakpoint/Locals/continue/stop/restart.
- Явная pinned подготовка adapter и проверки наличия tools только при запуске.
- Native E2E Windows+WSL2 и Ubuntu, команды/история/границы Mac отдельно.

## Capabilities

### New Capabilities

- bash-debug: IDE-SH-5, готовый DAP backend и общий keyboard workflow.

### Modified Capabilities

Нет; Bash run/tests IDE-SH-1–4 остаются отдельными существующими действиями.

## Impact

Небольшой Bash DAP module, existing dap.lua integration, explicit SDK preparer,
fixtures/E2E/registry/docs. Без новых plugin pins/backports, startup install,
изменения WSL default distribution или Docker/Desktop/WSL lifecycle.
