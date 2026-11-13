# Proposal

## Why

IDE-135, продолжение IDE-080/082 после Rust §227: Delve discovery уже отложен
до debug, но `go_env` и `parse_dlv_version` в plugins/dap.lua используют
синхронные subprocess. DapGoDlvInfo повторно выполняет тот же поиск. Это
блокирующая граница явного запуска/диагностики, не новая причина Mac shell
startup. Требование IDE-DAP-10 сохраняет отзывчивость при таком запросе.

## What Changes

- Native async Go/Delve probes в coroutine nvim-dap.
- Один `go env -json GOBIN GOPATH`, один список для вывода и выбора DapGoDlvInfo.
- Только metadata probe получает GOTOOLCHAIN=local; глобальный env и настоящая
  сборка/debug сохраняют выбранный пользователем toolchain.
- Сохранить overrides, version sorting, PATH/Mason/GOBIN/GOPATH и startup0.
- Native regression с настоящими Go/Delve, held callback и вводом; controls
  пассивного редактирования и реального первого/повторного debug/output.

## Capabilities

### New Capabilities

- `go-debug-discovery`: асинхронное разрешение инструментов Go debugging.

### Modified Capabilities

Нет. IDE-BOOT-4 и IDE-DAP-1 сохраняются; baseline IDE ещё не снята.

## Impact

Existing dap.lua, existing go-passive observer/E2E и выбранные controls,
OpenSpec/docs/history. Без cache/framework/backend или новых SDK/pins/patches.
Windows .cmd native smoke проверен отдельно; shell wrapper не требуется.
