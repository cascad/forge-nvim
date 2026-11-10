# Proposal

## Why

IDE-083: gpd открывает настоящее определение, но q вызывает E21 и оставляет
Peek открытым (6 native RED Windows/Ubuntu, FIXLOG §147). В plugins/ide.lua
семь list mappings заданы строками вместо ожидаемых Glance functions;
намерение клавиатурной навигации/закрытия фиксирует IDE-PANEL-9.

## What Changes

- Удалить лишний mappings override и использовать готовые Glance defaults
  для j/k/Enter/v/s/Esc/q, сохранив существующие entrypoints и оформление.
- Добавить постоянный native E2E клавиш закрытия, reference selection,
  перехода и splits с настоящим gopls; покрыть entrypoints gpd/gpr/gpt/gpi.
- Описать управление списком/preview и сохранить историю/платформенные gates.

## Capabilities

### New Capabilities

- `peek-navigation`: IDE-PANEL-9, клавиатурный preview символов и переход
  в код без ошибок от буквальных action strings. В main specs capability нет.

### Modified Capabilities

Нет изменений main specs.

## Impact

Только Glance opts в plugins/ide.lua; native E2E/fixtures/registry и docs/history.
Пины, LSP/backend и panel framework прежние. Windows/Ubuntu проверяются реально,
Mac/GUI отдельно. Выбор удаления дополнительных UI и IDE-084 не входит в fix.
