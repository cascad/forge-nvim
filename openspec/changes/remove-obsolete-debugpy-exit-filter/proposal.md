# Proposal

## Why

IDE-111: настоящий `python -m debugpy.adapter --forge-invalid-option` выходит
с кодом2, native stderr сохраняет argparse ошибку, но legacy benign_patterns
в plugins/dap.lua скрывает WARN по типу debugpy. Это против намерения IDE-DAP-5;
IDE-DAP-6 уточняет UI/Logs для настоящего debugpy. Source83cf655 RED подтверждён.

## What Changes

- Удалить широкое подавление debugpy exit WARN по имени Python executable.
- Сохранить backend классификацию client-close, raw logs и текущую Go/TCP policy.
- Добавить native E2E настоящего debugpy: exit2, UI/общие Logs, stderr и editor recovery.

## Capabilities

### New Capabilities

- `debug-adapter-lifecycle`: IDE-DAP-6, диагностика настоящего debugpy;
  capability IDE-DAP-5 уже описана в прежнем открытом change, основной baseline пока нет.

### Modified Capabilities

Нет.

## Impact

Только legacy notify wrapper plugins/dap.lua, E2E/registry и история.
Backend patch/SDK/pins не меняются. Windows source/target и normal pytest debug;
Ubuntu/Mac остаются отдельными платформенными проверками.
