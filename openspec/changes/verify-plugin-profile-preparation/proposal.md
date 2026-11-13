# Proposal

## Why

IDE-130: инструкция обновления перечисляла3 Lazy build при6 обязательных
backports. Native Neo-tree config отказал; E2E начинали с готовых plugins и
не проверяли эту инструкцию. Это пробел подготовки/проверок IDE-BOOT-1,
а не основание считать обычный запуск успешным по prepared fixtures.

## What Changes

- Исправить инструкцию: восстановить pin из lock при расхождении, явно
  подготовить все декларации существующим prepare-plugins.lua, затем restart.
- Добавить native E2E исходных6 payloads → общий applier → Files/Tests/Locals,
  без config ERROR, startup install и записи patches при открытии панели.
- Сохранить actual inventory/repair user profile и точные границы проверки.
- Записать новые жалобы Rust/Files как IDE-131/132, без смешивания причин.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет; skip_specs:true. Runtime/SDK/pins/порядок подготовки не меняются,
исправляются инструкция и регрессионная проверка существующего setup.

## Impact

plugin-backports.test.lua, инструкции, PROBLEMS/roadmap/FIXLOG/HISTORY/commands.
Actual Windows cache repaired offline; Linux/macOS новой итерацией не заявляются.
