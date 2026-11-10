# Proposal

## Why

IDE-085: strict search regression снова воспроизвёл qa! → SIGTERM на Windows
(21014452051400, source b679227). UI assertions PASS, native code=1/signal=15
после 2 s. Старые artifacts не показывают, был ли quit принят и до какого
этапа дошёл child. Увеличение timeout не даёт причины.

## What Changes

- Минимальный test-only trace: отправка/возврат write, состояние process handle,
  EOF/completion; native QuitPre/VimLeavePre/VimLeave с registration до init.
- Bounded detail flag для RPC activity; команды и пределы ожидания прежние.
- Сохранять nvim_error_event, прежде отбрасывавшийся клиентом, отдельно от exit.
- Реальные normal/намеренно задержанный QuitPre E2E доказывают наблюдаемость.
- Ограниченные повторы исходного search case и история фактов; зелёный повтор
  не закрывает IDE-085 без установленной причины/фикса.

## Capabilities

### New Capabilities

Нет, исключительно диагностика тестового каркаса, `skip_specs: true`.

### Modified Capabilities

Нет изменений пользовательского поведения/main specs.

## Impact

tests/lib editor RPC/process trace, новый native E2E/registry, docs/history.
Product Lua, pins, SDK и пределы ожидания/сигналов прежние. Windows/Ubuntu
последовательно; Mac/GUI непроверены. Docker Desktop/WSL не управляются.
