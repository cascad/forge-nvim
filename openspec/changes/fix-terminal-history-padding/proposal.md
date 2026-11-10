# Proposal

## Why

IDE-093: настоящий resize после before snapshot уменьшает viewport padding. Старый helper сравнивает полный terminal buffer включая пустые строки и сообщает потерю stdout при сохранённых текстах/channel/frame. Native RED и raw before/after уже записаны в §162/163.

## What Changes

- Для настоящего terminal buftype сравнивать историю без trailing empty rows; для REPL/других буферов сохранить точное сравнение.
- Не игнорировать внутренние пустые строки или потерю непустых строк.
- Unit loss/padding vectors и permanent native CodeLLDB resize E2E, также проверяющий UTF8 trace и реальный buffer/channel.

## Capabilities

### New Capabilities

Нет: test-only, skip_specs:true.

### Modified Capabilities

Production Output поведение не меняется.

## Impact

tests/lib/output_policy.lua, unit/native regression, registry и история. Без новых production modules/SDK/LSP.
