# Proposal

## Why

После матрицы языков (77e0fa9) Go debug/tests имеют реальный регресс, но
настройки gopls/cmp/format не подтверждены пользовательским языковым сценарием.
Следующий шаг roadmap — доказать существующий Go workflow до добавления языков.

## What Changes

- Явная переносимая подготовка gopls v0.23.0 и gofumpt v0.9.2 с Go 1.26.0,
  проверкой module metadata/SHA, без установок при старте редактора/теста.
- Постоянные реальные editor E2E: definition/references, multi-file rename,
  LSP completion, diagnostics/исправление и format/save, включая LSP fallback.
- Включение тестов в registry и явную подготовку Ubuntu image; Windows temp/
  build остаются на F:, тяжёлые прогоны последовательные.
- Честные результаты/история/команды и обновление языковой матрицы.

## Capabilities

### New Capabilities

Нет. skip_specs: true — change добавляет тесты/tooling существующего поведения.
Найденный runtime баг сначала получает ID и отдельную delta, затем исправление.

### Modified Capabilities

Нет; публичное поведение/config редактора пока не меняется.

## Impact

tests/e2e, tests/registry.lua, Dockerfile и документация. Go dependencies только
в явно подготовленном тестовом каталоге; lock/plugins/SDK редактора не меняются.
Mac/GUI непроверены без реального запуска. Docker lifecycle не входит в работу.
