# Proposal

## Why

IDE-091: native Rust probe source 5d07d2b показал, что Space du закрывает sidebar, но оставляет PTY. В activities.debug_filetypes и close_debug отсутствует dap-terminal, хотя он уже отдельный компонент. Это пробел общей группы Debug; исходный единичный sidebar failure IDE-090 остаётся отдельной диагностикой.

## What Changes

- Включить существующий PTY компонент в общий Debug visibility/close, без уничтожения буфера или сессии.
- Добавить реальные Rust/CodeLLDB E2E для всей группы и случая с одним видимым PTY.
- Сохранить q как скрытие текущего компонента, общий toggle как скрытие/возврат Debug.

## Capabilities

### New Capabilities

- `ide-debug-group`: IDE-PANEL-13 — общий Debug toggle включает PTY; дополняет IDE-PANEL-2/11.

### Modified Capabilities

Нет изменений опубликованной базовой линии.

## Impact

Общий Lua activities, native editor tests и руководства/история. SDK, LSP, Docker/WSL не меняются. Windows проверяется здесь, Ubuntu/Mac сохраняют явные gates.
