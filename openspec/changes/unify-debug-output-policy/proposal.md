# Proposal

## Why

IDE-086: ручной Debug View (`Space m d`, `Space dD/du`) выбирает Console для Rust/Python/Node и после выхода Go, хотя F5 выбирает PTY или REPL. Продолжение Rust через F5 скрывает уже существующий PTY. Намерение IDE-PANEL-2 и IDE-DAP-1 — доступный вывод без потери паузы/истории; новый контракт IDE-PANEL-11 уточняет единый выбор.

## What Changes

- Один resolver каналов в `ide.dap`: конфигурация для запуска, видимый/последний канал для ручного открытия.
- Восстановление существующего PTY при hide/reopen и continue; создание свежего PTY остаётся у runInTerminal.
- Legacy `Space D c` использует тот же Output, что `Space w c`; `Space D v` по-прежнему Variables.
- Постоянные native E2E на реальные Go/Rust/Python/Node адаптеры и историю вывода.

## Capabilities

### New Capabilities

- `ide-output-policy`: IDE-PANEL-11, выбор и восстановление Debug Output. Базовой nvim-спеки ещё нет.

### Modified Capabilities

Нет.

## Impact

`ide/dap.lua`, существующие компоненты `ide/init.lua`, DAP listeners и keymaps. Зависимости, протокол DAP, адаптеры и платформенные SDK не меняются. macOS требует отдельного native прогона владельцем.
