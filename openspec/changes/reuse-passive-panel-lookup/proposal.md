# Proposal

## Why

IDE-080, обзор §184: component visibility и default focus повторяют пассивный
обход окон из ide.activities. Можно удалить два дублирующих цикла, сохранив
пользовательский Space w и существующие правила выбора.

## What Changes

- Использовать существующий passive finder для visibility и default focus.
- Сохранить порядок native windows текущего tab, несколько FT, custom focus,
  no-match и вызов source predicate только после подходящего FT.
- Добавить постоянные native E2E и сравнить source baseline с refactor.

## Capabilities

### New Capabilities

Нет. Это внутренний refactor, skip_specs:true; новых требований нет.

### Modified Capabilities

Нет. Совместимость с прежними IDE-PANEL-1/2 и другими рабочими панелями
проверяется существующими и новыми E2E, без изменения delta spec.

## Impact

Два существующих Lua module, tests/registry и review/docs/history.
Без нового module/плагина, изменения pins, backend, platform веток или UI.
