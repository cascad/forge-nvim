# Proposal

## Why

IDE-080: plugins/dap.lua смешивает Go/Delve discovery, Cargo target selection,
Python/venv/debugpy resolution с запуском и панелями. После обзора владелец
разрешил узкое разделение этих обязанностей с сохранением поведения.

## What Changes

- Перенести существующие helpers в forge/dap/go.lua, rust.lua, python.lua.
- Маленький context.lua содержит только прежние normalize_path,
  with_launch_buffer и current_launch_path; без нового состояния/dispatcher.
- Main plugin использует прямые imports/aliases; тела функций, native APIs,
  cancellation/cwd/launch.json/options/приоритеты SDK не меняются.
- Source fidelity и существующие native E2E Windows/Ubuntu после цельной
  реализации: Go passive discovery/late override, Cargo cancel/stale/выбор
  второго bin, Python default/project/pytest debug, missing-adapter controls.

## Capabilities

### New Capabilities

Нет: skip_specs=true, перенос кода без изменения контрактов.

### Modified Capabilities

Нет. IDE-DAP-4/5/7/8/9/10 и прежние user entrypoints сохраняются.

## Impact

plugins/dap.lua и4 внутренних Lua modules; existing E2E, roadmap/review,
FIXLOG299/HISTORY/commands207. Pins/SDK/backports и SQL scope прежние.
