# Proposal

## Why

IDE-098: Ubuntu native output-resize на source72cb336 дал FAIL «Fixture did not exercise raw padding mismatch», хотя terminal window уменьшился13→10, а после snapshot буфер ещё содержал13 строк. Neovim откладывает refresh terminal buffer; следующий snapshot того же буфера уже содержит меньше padding. Это race диагностической фикстуры IDE-093, не потеря stdout и не spec-level product изменение.

## What Changes

- После настоящего UI resize дождаться наблюдаемого уменьшения окна и обновления terminal buffer до его viewport; затем продолжить прежний hide/reopen.
- Сохранить strict raw mismatch, markers/channel/session/history и native cleanup assertions; записать actual geometry для доказательства предусловия.
- Проверить один общий сценарий Windows/Ubuntu, сохранить первый source FAIL, историю и Ubuntu gates текущих исправлений.

## Capabilities

### New Capabilities

Нет: test-only diagnostic readiness, `skip_specs: true`.

### Modified Capabilities

Нет. Main specs описывают WezTerm; product Output и его semantic comparison прежние.

## Impact

tests/diagnostics/output-toggle.lua и output-resize E2E, тестовая документация/история. Проверенный private resource override оформляется как optional tests/containers/limits.yaml с теми же resolved значениями. Общие Lua modules, plugins/SDK/pins, сроки ожидания и Docker/WSL lifecycle не меняются.
