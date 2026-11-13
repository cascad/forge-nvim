# Proposal

## Why

Продолжение IDE-080/131/132 после отложения натурных проверок владельцем.
В `plugins/dap.lua:rust_current_program` F5 выполняет настоящий `cargo metadata`
через синхронный `vim.fn.system`. Медленный Cargo удерживает интерфейс перед
выбором цели, хотя preLaunchTask уже использует штатный Overseer.
IDE-134 / IDE-DAP-9 фиксируют отдельную границу запуска, не причину старых
плавающих зависаний или latency пользовательского проекта.

## What Changes

- Native async Cargo и существующая coroutine option nvim-dap для program.
- Сохранить текущие правила bin/example, picker/отмену и ошибки metadata.
- При смене cwd до результата отменять старый запуск через dap.ABORT.
- Permanent E2E настоящего Cargo: source sync RED, UI/input до доставки
  настоящего результата, cancel picker и смена проекта; прежний IDE-DAP-7 control.

## Capabilities

### New Capabilities

- `rust-debug-responsiveness`: отзывчивость разрешения Cargo target при F5.

### Modified Capabilities

Нет. IDE-DAP-7 сохраняется; baseline IDE ещё не снята.

## Impact

Existing Rust program resolver, existing Rust E2E и ограниченный IO observer,
OpenSpec/docs/history. Общая native API граница для Windows/macOS/Ubuntu;
без нового backend/cache/framework, обновления SDK/pins или plugin patches.
