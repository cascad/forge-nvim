# Proposal

## Why

IDE-062: SQLLogicTest уже работает, но `gr`/Space l r не находят semantic references:
SQLS 0.2.48+forge.1 не объявляет provider и не обрабатывает textDocument/references.
Совпадение текста `id` смешивает разные таблицы и области видимости и не выполняет
требование владельца к SQL в общей IDE.

## What Changes

- Семантические references таблиц, колонок и локальных SQL symbols через обычные
  LSP mappings, quickfix и переход обратно в код, без отдельного UI/набора клавиш.
- SQL scopes: FROM/JOIN, aliases, вложенные/correlated SELECT, CTE и derived tables,
  projection aliases, обычные INSERT/UPDATE/DELETE. Одинаковые имена разрешаются
  по области видимости и схеме выбранного подключения.
- Поиск в SQL-файлах текущего workspace, включая закрытые файлы; didOpen/didChange
  перекрывают текст на диске. Чужие workspace, comments/literals, неоднозначные
  или неразрешённые имена не превращаются в совпадения по строке.
- Расширение существующего закреплённого native SQLS SDK: уже имеющиеся AST,
  schema cache и один LSP process на workspace. Установка остаётся явной.
- Постоянные native SDK и настоящие editor E2E, source baseline без provider,
  Windows/Ubuntu проверки, история и честные ограничения macOS/диалектов.

## Capabilities

### New Capabilities

- `sql-workflow`: ADDED IDE-SQL-9 semantic references. Capability уже описана
  открытыми add-sql-edit-query-workflow/add-sql-test-workflow, но main baseline
  ещё не содержит её. Новый ID дополняет их без переписывания IDE-SQL-1–8.

### Modified Capabilities

Нет. Main specs содержат только WezTerm/macOS installer; существующие SQL
query/tests и их lifecycle не меняются.

## Impact

`scripts/sdk/sqls*`, `tests/e2e/sql_sdk.py`, explicit SQL preparation/container
recipe и fixtures, LSP protocol boundary при необходимости, постоянные SQL
references E2E/реестр, docs/PROBLEMS/FIXLOG/HISTORY/команды. Нового сервера,
глобального Python runtime или фоновой установки SDK не требуется.

Не заявляется универсальная поддержка произвольных vendor extensions или
procedural SQL: неизвестная конструкция должна давать явное ограничение,
а не правдоподобные неверные references. Это не снимает обычные SQL scopes/DML
с критериев завершения этого change.
