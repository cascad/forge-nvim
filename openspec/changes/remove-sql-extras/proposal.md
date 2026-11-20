# Proposal

## Why

Владелец явно выбрал удалить дополнительные SQL-функции и собственные слои:
DB connections/schema-aware actions, queries/Results и SQL assertions.
Базовые подсветка, upstream Sqruff LSP и форматирование сохраняются.
Legacy IDE-SQL-1…9 больше не задают желаемый объём продукта; IDE-BOOT-34 остаётся.

## What Changes

- Удалить custom SQL runtime/Results/Neotest adapter, команды и связи панелей.
- Удалить SQLS SDK/patch/build, собственный Rust test runner и их packaging/
  delivery tests. Sqruff/parser preparation оставить штатной, без Go/SQLite.
- Убрать SQL bundle readiness/inventory и image build stages дополнительных
  tools; native Sqruff resolution использует общий PATH/Mason/tool_paths.
- Удалить retired advanced tests/fixtures, сохранить и расширить sql-basic
  native E2E: базовый workflow и отсутствие удалённой поверхности/adapter.
- Поддержать уже разобранные REMOVED в trace metadata: старые SQL требования
  остаются известны истории, но не требуют E2E снятых возможностей. Generic
  IDE-TEST-5/6 сохраняются с проверками остальных adapters.
- Не удалять файлы/БД/SDK уже установленного пользователя.

## Capabilities

### New Capabilities

- sql-baseline: IDE-SQL-10, Sqruff baseline без дополнительных SQL layers.

### Modified Capabilities

- sql-workflow: REMOVED IDE-SQL-1…9; диагностика/format сохраняются IDE-BOOT-34,
  generic IDE-TEST-5/6 сохраняются. Main specs содержат WezTerm/macOS, не IDE;
  это delta к существующим IDE changes, main specs не переписываются.
- managed-debug-test-tools и basic-language-installation: убрать специальную
  SQL delivery/readiness policy из IDE-BOOT-23/35, сохранив общие archive checks.

## Impact

Runtime SQL/панели/tests, SQL SDK/package/preparation/inventory/container stages,
registered tests и trace metadata, текущие guides/plan и FIXLOG300/HISTORY/
commands208. Go/Rust/Python/Node/Bash SDK, plugins66 pins и6 backports прежние.
