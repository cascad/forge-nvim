# Proposal

## Why

IDE-109: после `:Neotree filesystem left` общие hide/toggle/layout не учитывают
настоящее окно: `ide.state.refresh_slot` проверяет только прежний ID.
Это нарушает намерение единого управления IDE-PANEL-21; `controls.hide`
компенсирует расхождение повторным прямым закрытием backend.
IDE-110: DAP Terminal open/close обходят все вкладки при tab-local is_open;
настоящий CodeLLDB/PTY воспроизводит закрытие чужого вида и пропуск Show.

## What Changes

- Общие переходы учитывают видимые зарегистрированные компоненты текущей вкладки,
  включая открытые штатными командами плагинов.
- Show оставляет один компонент выбранного слота, принимая уже открытый без
  пересоздания; Hide конкретного компонента сохраняет остальных.
- Toggle/layout/focus используют ту же фактическую видимость.
- Удаляется компенсационное закрытие из controls; способы запуска backend,
  существующие сочетания, содержимое и процессы сохраняются.
- DAP Terminal показывает и скрывает текущую вкладку, сохраняя чужой вид.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-21, согласованные переходы штатных окон и IDE;
  продолжение capability из прежних panel changes.

### Modified Capabilities

Нет: основная базовая линия IDE ещё находится в changes.

## Impact

`ide/state.lua`, `ide/controls.lua`, source-specific закрытие Neo-tree в
`ide/init.lua`; постоянный native editor E2E и соседние панели Windows/Ubuntu.
Новых зависимостей, менеджера окон, фонового polling и изменений SDK нет.
Mac и физическая клавиатура проверяются отдельно.
