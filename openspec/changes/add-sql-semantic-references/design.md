# Design

## Context

SQLS 0.2.48+forge.1 уже готовится из SHA-checked source с небольшим comments patch
(`scripts/sdk/sqls.json`, `tests/e2e/sql_sdk.py`). Один client на workspace
обслуживает language actions и SQL query. References отсутствуют в switch и
initialize capabilities. Upstream rename сравнивает identifier names в statement;
это не binding resolver и его алгоритм нельзя копировать для IDE-062.

AST probe на закреплённом source действительно выделяет MemberIdentifier,
Aliased, Statement и вложенные Parenthesis, включая CTE. Уже есть database cache
со schema/table/column metadata. Проба сохранена в ignored .tests; существенные
случаи должны стать постоянными tests, а не доказательством по описанию.

## Goals / Non-Goals

**Goals:** один native SQLS process, существующие клавиши и quickfix, настоящая
scope/binding модель поверх существующего AST, immutable explicit SDK и реальные
native/editor проверки Windows/Ubuntu. Приоритет корректности locations и symbols.

**Non-Goals:** новый handwritten SQL lexer/parser в Lua, отдельный Python LSP,
замена query/format/test workflow, SQL execution ради references, procedural
debugger и недоказанная универсальная поддержка vendor extensions.

## Decisions

1. Расширить native SQLS закреплённым patch/overlay, сохраняя upstream source SHA,
   Go locks, before/after SHA изменённых файлов и новую явную SDK версию.
   Handler объявляет настоящий references provider и отдаёт LSP locations.
   Старый SDK не маскируется правкой capabilities в Neovim. Альтернатива
   RainLib/lsp_sqls проверена: columns там сравниваются по имени без schema binding;
   Postgres Language Server в исследованном source не объявляет references.
2. Сначала native AST, затем relation scopes и symbols. Physical identity включает
   schema/table/column текущего connection. Alias identity включает URI/scope и
   декларацию; CTE/derived output columns имеют собственную export identity.
   FROM/JOIN sources собираются до разрешения projection/WHERE expressions.
   Nested SELECT имеет parent scope для correlated lookup; shadowing и ambiguity
   не устраняются выбором первого совпадения. Projection alias и CTE declaration
   отдельно отмечаются для includeDeclaration. DML target supplies column context.
3. Индекс строится по запросу из SQL-файлов rootUri/rootPath этого client. В Git
   использовать отслеживаемые и неигнорируемые untracked файлы; без Git — native
   обход с исключением служебных/generated каталогов. Канонические пути/realpath
   проверяются перед чтением, symlink наружу не расширяет workspace. Открытые
   buffers s.files перекрывают диск, но только в том же workspace. Повторный
   запрос учитывает изменения/удаления, без фонового daemon и несвежего индекса.
4. Schema cache берётся из существующего worker выбранного connection, без
   выполнения пользовательского SQL. Неподготовленная схема/неоднозначный target
   возвращает объяснимую LSP error; unsupported construct не подменяется token
   matching. Locations детерминированно сортируются и дедуплицируются. Индекс
   проверяет context cancellation; пределы/ошибки чтения не дают молчаливый
   частичный успешный результат.
5. SQLS lexer/ranges используют codepoint coordinates; существующая boundary
   выставляет utf-32. Новый handler использует ту же систему, без rename +1
   workaround для references. Реальные Unicode/quoted quickfix transitions
   проверяются через Neovim, не только сравнением protocol JSON.
6. Не менять общий gr/Space l r при наличии настоящего provider. Если для error
   требуется boundary hook, он не фабрикует results и не скрывает отсутствие
   backend. Чужие languages, query/Tests/panels и 67 plugin pins сохраняются.

## Risks / Trade-offs

- SQLS AST не является готовым binder → scope/CTE/DML fixtures и независимые
  expected locations, в том числе отрицательные. Если AST теряет нужную структуру,
  остановить расширение этой части и зафиксировать доказательство; не заменить
  grammar regex и не объявить весь IDE-062 завершённым по простому SELECT.
- Schema/dialect case rules → native schema-aware identity и quoted identifiers,
  явные platform/dialect результаты. SQLite fixtures не доказывают внешние DB.
- Проектный индекс и unsaved buffers → closed files, didChange/didClose, удаление,
  ignored files, symlink и второй workspace в настоящих E2E.
- Размер source patch → модуль resolver отдельно от JSON-RPC handler, без новой
  framework/dependency. Проверять upstream query tests и неизменные Go locks.

## Migration Plan

Сначала новый editor case против forge.1 даёт целевой RED (реальный gr и отсутствие
provider), сохраняя baseline SDK/test/config. Затем binder, handler/SDK metadata,
native tests и explicit candidate build в отдельном output. Native process/editor
E2E Windows, затем уже доступный Ubuntu engine; если его нет, не поднимать Desktop.
Проверить query/Tests/panels regression, историю и strict validation, коммитить
завершённые шаги. macOS/GUI остаются открытыми до запуска владельцем. Откат SDK
явно возвращает предыдущую закреплённую версию, не меняя installed profile скрыто.
