# Design

## Context

См. proposal. Stack §275 показывает throw из node.command → ts_ls.root_dir.
Strict override нужен setup/preflight, picker и ForgeToolPaths; заменять его
молчаливым nil нельзя. Runtime callbacks должны обрабатывать ошибку у входа.

## Goals / Non-Goals

**Goals:** доступное редактирование, source/reason в Logs, отказ без fallback/
task/session, повтор после исправления пути, сохранение штатных LSP/DAP APIs.
**Non-Goals:** менять schema/SDK policy, придумывать серверы, управлять Docker/WSL,
перезапускать весь регресс или исправлять остальные отказы checkpoint.

## Decisions

- Оставить strict resolvers. Общий protected вызов используется только на runtime
  boundaries; LSP root guard не вызывает on_dir при nil/error и ограничивает
  повтор уведомления для того же buffer/server/reason. При успехе guard очищается.
- Runtime предупреждение короткое; полная причина с источником сохраняется в
  общей Logs. Это не маскирует ошибку и не меняет глобальный notification backend.
- Node default launch config не ищет SDK до readiness. Adapter/run используют
  проверенные Node/entrypoint, а Bash adapter проверяет свои зависимости до callback.
- Node/Bash LSP и условия Prettier не пропускают ошибки проверки в event loop.
  Native RPC transport остаётся прежним; OS spawn races обрабатывает Neovim,
  искусственный RPC client или private cancellation API не создаётся.
- E2E: прежние missing/recovery cases плюс project/user JSON, invalid paths,
  no-blocking edits/save, отсутствие task/session/install/fallback и retry.
  Один affected file batch на Windows/Ubuntu после цельного кода; Bash missing
  checks на Windows не должны запускать WSL; native Bash workflow — Ubuntu.

## Risks / Trade-offs

- Лишние предупреждения LSP → дедупликация по буферу и reset при успешной проверке.
- Потеря причины → source/reason в Logs и сохранённый strict report/preflight.
- Непреднамеренный fallback → отрицательные controls при наличии рабочей PATH копии.
- Mac недоступен → общий Lua код, нативная приёмка отдельно владельцем.
