# Proposal

## Why

IDE-136: после настройки LSP ранняя Rust preparation вызывает vim.lsp.start
напрямую и обходит штатное vim.lsp.enable('rust_analyzer', false). Проверки
нет ни до Cargo metadata, ни после асинхронного ответа. Это может вернуть
отключённый сервер и фоновую работу. IDE-RUST-3 фиксирует ownership native
enable/disable без нового контроллера. Native root/library algorithm сохраняется.

## What Changes

- Проверять native enabled state до metadata и перед запуском клиента.
- Отмечать пропуск в существующих IDE Logs.
- Сохранить обычное native повторное включение и enabled warmup/reuse.
- Permanent source/target E2E: initial disable и disable при ожидающем
  настоящем metadata ответе; controls enabled warmup, completion, общий observer.

## Capabilities

### New Capabilities

- `rust-language-control`: ранняя подготовка подчиняется native LSP control.

### Modified Capabilities

Нет. IDE-RUST-2 сохраняется; baseline IDE ещё не снята.

## Impact

forge.rust_project, existing Rust E2E/Cargo observer, OpenSpec/docs/history.
Без изменения root resolver, SDK, pins, plugin patches или собственного
enable-state/cache/process manager. Все ОС используют один native API.
