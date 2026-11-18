# Proposal

## Why

§286–287 проверили язык/format в установленном Default. Следующий пункт IDE-138 —
исполнение программ, native DAP и Neotest для Go/Rust/Python/Node внутри того же
комплекта. Source fixtures не заменяют managed adapter readiness.

## What Changes

- Дополнить existing installed diagnostic driver режимом runtime workflow.
- Настоящие приложения/тесты, native запуск DAP, breakpoint/evaluate/continue/
  output и Neotest passed/output. Готовые pytest/Jest dependencies проекта
  подготавливаются явно offline, SDK и IDE packages не устанавливаются.
- Зафиксировать actual failures и границы; product bug — отдельный change.

## Capabilities

Только verification существующих contracts, skip_specs=true; поведения не меняем.

## Impact

Diagnostic helper/observer и история. Существующий RPC/process transport,
готовые owned kits; без новых SDK managers, сервисов и полного regression loop.
