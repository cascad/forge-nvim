# Proposal

## Why

IDE-076: выбранные владельцем цельная рамка и цвет пока показаны только на
временном zoom. Нужен ограниченный рабочий пилот, чтобы оценить стоимость
постоянного оформления до распространения на остальные панели.

## What Changes

- Явно включаемый пилот Code + Locals с настоящими native буферами, рамками
  и единственным владельцем размещения этих двух окон.
- Живые переменные после шага/следующего breakpoint, прежние общие клавиши,
  resize, скрытие/возврат Locals и выход в прежнюю раскладку.
- E2E Windows/Ubuntu и оценка цены подхода; Mac/physical GUI отдельным gate.

## Capabilities

### New Capabilities

- `bordered-locals-pilot`: IDE-PANEL-20, явный рабочий эксперимент с рамками.

### Modified Capabilities

Нет. Default layout и существующие спецификации не меняются.

## Impact

Небольшой opt-in layout, границы ide main/controls/sidebar; готовый DAP UI и
Neovim API. Без новых зависимостей, смены pins, LSP и backend forks.
