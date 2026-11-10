# Proposal

## Why

IDE-090: §162 воспроизвёл reopening после явного hide. Watchdog800ms после initialized видит отсутствующий bottom и открывает Debug заново (native caller plugins/dap.lua:1419). Он не отличает startup failure от выбора пользователя и может попасть в q/toggle.

## What Changes

- Удалить obsolete watchdog и его visibility helper, использовать существующие initialized/runInTerminal/stopped события.
- Скрытый пользователем Debug остаётся скрытым до ручного открытия или нового настоящего stopped event.
- Добавить native running Rust regression: hide до800ms, отсутствие reopening, новый breakpoint возвращает sidebar/тот же PTY, F5 сохраняет вывод.

## Capabilities

### New Capabilities

- `debug-visibility`: IDE-PANEL-14 — явное скрытие не отменяет startup recovery.

### Modified Capabilities

Нет изменений опубликованной базовой линии; дополняет IDE-PANEL-2/11/13.

## Impact

Общий plugins/dap.lua становится короче. Native E2E, руководство/история. Без новых timers/state/LSP/SDK и управления Docker/WSL.
