# Proposal

## Why

IDE-119: два managed debugpy fallback в plugins/dap.lua жёстко используют
Windows Scripts/*.exe. Общий проектный selector IDE-PY-1 не доказывает эту
ветку: существующая fixture ставит debugpy в project venv. Нужны native
managed-adapter и managed-Python scenarios до исправления Unix layout.

## What Changes

- Уточнить IDE-PY-2: adapter environment и project interpreter раздельны;
  managed venv использует native Windows/POSIX layout без startup install.
- Добавить real debugpy E2E: managed launcher, managed Python fallback,
  explicit adapter и explicit adapter Python; project venv без debugpy.
- Сохранить frozen source до изменения и исправить существующую границу DAP,
  сохраняя порядок explicit/project/PATH/Mason, F5 и output/session policy.
  Native Unix source/target остаётся обязательным gate при unavailable engine;
  Windows control не подменяет этот результат и не закрывает IDE-119.

## Capabilities

### New Capabilities

- `python-interpreter`: IDE-PY-2 managed debug adapter, дополнение прежнего
  IDE-PY-1 из fix-python-project-interpreter, основная IDE baseline ещё в changes.

### Modified Capabilities

Нет.

## Impact

Existing plugins/dap.lua и native layout helper при необходимости, permanent
E2E/fixture/registry, test docs/roadmap/история. Без общего tools framework,
новых LSP/SDK/pins или переноса project roots. Windows/Ubuntu native,
Mac отдельно; unavailable engine не подменять platform simulation.
