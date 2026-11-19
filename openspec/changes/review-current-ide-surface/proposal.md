# Proposal

## Why

IDE-080: прежний обзор отражает несколько исторических срезов, а установка,
SDK и языковые workflows заметно изменились. Перед рефакторингом нужен текущий
список фич, владельцев поведения и конкретных кандидатов, без удаления наугад.

## What Changes

- Сверить67 pins, собственные modules/installer и6 plugin backports с текущим
  source8d721c3; отделить source facts от исторических runtime результатов.
- Обновить FEATURE_REVIEW и PLUGIN_INVENTORY: оставить/упростить/решить с
  владельцем, цена и проверяемый эффект. Старый обзор сохранить как историю.
- Зафиксировать IDE-146/WF-14: выделение → active integrated terminal,
  reveal/reuse/create, portable hotkey и будущие E2E. Runtime не меняется.
- Обновить roadmap/HISTORY/FIXLOG/commands и проверить ссылки/inventory.

## Capabilities

### New Capabilities

Нет: только обзор и документация; skip_specs=true.

### Modified Capabilities

Нет. Возможное удаление дополнительных SQL-функций — отдельное решение и change.

## Impact

Документация и план. Code/lock/SDK/plugins/settings остаются прежними.
Native Omarchy/macOS gates сохраняются; новые behavioral PASS не заявляются.
