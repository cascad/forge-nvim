# Proposal

## Why

IDE-053: Python pytest debug доходит до успешного результата и target exit 0,
но nvim-dap сам прерывает stdio adapter при client close и затем выдаёт WARN
о его exit 1. Это перекрывает UI результат. RED 12313750968000/12489517786400,
pinned dap/session.lua: onexit → stdin close → sigint, process callback WARN.
IDE-DAP-1/2 описывают output, IDE-DAP-4 — codelldb discovery; classification
ожидаемого adapter shutdown ими не определена.

## What Changes

- Зафиксировать client-initiated close до process callback и отличать его от
  неожиданного падения; raw process exit code не переписывается.
- Явный pin/SHA backport nvim-dap через существующий build/prepare механизм,
  без Windows-only ветки, transport replacement и runtime записи source.
- Постоянный real pytest debug RED/GREEN и negative E2E неожиданного adapter
  exit с сохранённым WARN; Node/Go DAP регресс, история/команды.

## Capabilities

### New Capabilities

- debug-adapter-lifecycle: IDE-DAP-5 — ожидаемое закрытие и неожиданный adapter exit.

### Modified Capabilities

Нет основной DAP capability в specs; прежние delta requirements не меняются.

## Impact

Pinned nvim-dap patch/build, Python workflow E2E и docs. Зависимости явно
подготавливаются, startup пассивный. Текущая логика сигналов/таймаутов и raw
exit logging остаётся; ошибки adapter до запроса client close не подавляются.
