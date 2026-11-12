# Proposal

## Why

IDE-112: F7 → Space w i из normal code buffer открывает Logs, затем поздний
F7 возвращает курсор в code. Source RED без DAP подтверждён. Общий helper
after_normal_mode в keymaps.lua всегда планирует action, даже когда normal
уже активен; та же граница используется window cycle/buffer cycle/close.
IDE-PANEL-22 задаёт порядок этих normal-команд, сохраняя другие режимы.

## What Changes

- Выполнять action сразу, если normal mode уже активен.
- Сохранить exit/feedkeys/scheduling для insert/replace/visual/terminal.
- Постоянные source/target E2E для порядка focus/cycle/close и mode controls;
  обычный сохранённый файл закрывается до следующего выбора панели.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-22, порядок normal команд; основная IDE baseline
  пока в changes, прежние IDE-PANEL-1/21 сохранены.

### Modified Capabilities

Нет.

## Impact

Один helper config/keymaps.lua, native E2E/registry и история. Panel owners,
backend/SDK/deps не меняются. Windows проверяется сейчас, Ubuntu/Mac отдельно.
