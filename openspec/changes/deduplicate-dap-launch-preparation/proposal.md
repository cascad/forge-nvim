# Proposal

## Why

F5 и Space dP в plugins/dap.lua повторяют подготовку source/UI и цепочку
open/reset/run. Следующий срез IDE-080 сокращает эти независимые маршруты
в одном существующем модуле. Новый native CodeLLDB baseline проходит до
правки: F5/default, project single/multiple, args ${file}, fresh PTY и cancel.

## What Changes

- Общая подготовка действия: terminal mode → launch buffer → вид сессии.
- Общий запуск конфигурации: UI → codelldb reset → Node readiness →
  with_launch_buffer → dap.run, в прежнем порядке.
- Удаление промежуточного run_debug_choice и вложенного go из picker.
- Постоянный E2E для ранее не покрытого Space dP, baseline PASS→PASS.

## Capabilities

### New Capabilities

Нет. skip_specs=true: чистый refactor, поведение IDE-DAP-1 сохраняется.

### Modified Capabilities

Нет.

## Impact

Только plugins/dap.lua, native E2E/registry и история. Registry/state/Edgy,
adapters, PTY implementation, setup/SDK/pins не меняются. Windows проверяется
сейчас; Ubuntu source/target и Mac остаются обязательными открытыми проверками.
