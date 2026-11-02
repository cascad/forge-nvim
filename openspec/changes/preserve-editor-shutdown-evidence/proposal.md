# Proposal

## Why

IDE-047: в двух Ubuntu Gitsigns E2E первичный RPC timeout сменился ошибкой
stop_process (tests/lib/editor.lua:21); два собственных child оставались Sl
минуты после SIGTERM. Нужны надёжное завершение тестовых процессов и сохранение
первичной ошибки. Причина самого RPC зависания пока не установлена.

## What Changes

- Отделить test-only lifecycle helper: qa!, прежние 2s, SIGTERM/2s,
  SIGKILL/2s для собственного child; принудительное завершение остаётся FAIL.
- Сохранять PID, этапы/время/exit и первичный RPC timeout до/после остановки.
  Передавать исходное исключение из двух затронутых Git wrappers и startup.
- Добавить реальные process E2E: обычный RPC child; POSIX остановленный SIGSTOP
  child, настоящий 10s RPC deadline, обязательный cleanup после теста.
- Сохранить RED на исходной функции, проверить Windows/Ubuntu и историю.

## Capabilities

### New Capabilities

Нет: skip_specs=true, меняется тестовая инфраструктура.

### Modified Capabilities

Нет: runtime редактора/SDK/плагинов и пользовательские команды не меняются.

## Impact

tests/lib/editor_process.lua, editor.lua/editor_rpc.lua, два Gitsigns wrappers,
новый зарегистрированный process E2E, docs/FIXLOG/HISTORY/команды. Контроль
только собственного child handle; без Desktop/WSL lifecycle и поиска/убийства
процессов по имени. Зелёный повтор Git не закроет неизвестный первичный RPC.
