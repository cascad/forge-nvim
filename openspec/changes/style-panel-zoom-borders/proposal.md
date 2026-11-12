# Proposal

## Why

Владелец выбрал цельные цветные рамки Termide (IDE-076). Обычный zoom уже
имеет native border, но повторяет название в winbar и не различает фокус
цветом. Переносим проверенный стиль в повседневный Space w z.

## What Changes

- Единый цветной border и название для всех панелей общего zoom.
- DiagnosticInfo при фокусе, Comment при открытой поверх справке.
- Название и подсказка возврата в рамке, без дублирующего winbar overlay.
- Постоянный native RGB E2E внутри существующего debug-panels; один selected прогон.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-24, оформление общего zoom; capability пока описана активными changes и ещё не перенесена в основную базовую линию.

### Modified Capabilities

Нет изменений прежних требований.

## Impact

ide/controls.lua, existing debug-panels E2E, руководства/история. Backend,
обычные split и opt-in Code/Locals pilot сохраняют прежнее размещение.
