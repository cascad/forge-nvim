# Proposal

## Why

После Bash следующий языковой этап roadmap — SQL. В baseline be5b6bc нет
SQL LSP/formatter/parser preparation, подключения к БД и выполнения SQL из
редактора (IDE-060). Native probe sqls 0.2.48 также выявил ошибку первого
символа rename и нестандартные Unicode координаты (IDE-061); нужны исходный
RED и регресс, а не доверие advertised capabilities.

## What Changes

- Явно подготовленные sqls для схемы/completion/definition/alias rename/hover
  и sqruff для диагностики/форматирования, общие действия и ключи редактора.
- SQLS native JSON configuration .sqls.json, выбор connections без показа
  credentials, native backend для SQLite/PostgreSQL/MySQL и других SQLS drivers.
  SQLite — воспроизводимый E2E backend, не ограничение списка пользовательских БД.
- SQLRun всего текущего buffer или точного visual selection, результат/ошибка
  в SQL Results через общую модель панелей; SQLConnect/SQLResults/SQLStop.
- Исправление подтверждённого IDE-061 на границе SQLS protocol и проверка
  Unicode/первого символа alias. Запрос исполняет снимок выбранного текста.
- Явная pinned подготовка native tools/parser, Windows E2E и source RED,
  Ubuntu команды/image, история и обновлённая матрица. Startup без установок.
- IDE-063: восстановить общий запрет форматирования на autosave через
  публичные события закреплённого auto-save.nvim; явное save форматирует.
- IDE-064: диагностика Sqruff через async native CLI/stdin, поскольку 0.44.0
  LSP теряет parse-errors/dialect overrides; debounce/cancel и защита от старых ответов.

Этот change покрывает editing/query workflow. SQL test framework/Neotest
остаётся следующим обязательным пунктом полного SQL roadmap; отсутствие
SQLS references provider не объявляется семантическими references. SQL
procedural debugger и другие СУБД требуют соответствующего backend/сценария.

## Capabilities

### New Capabilities

- `sql-workflow`: IDE-SQL-1/2/3/4 — язык, format/diagnostics, подключения/
  query/results и доступность без tools. Постоянные real editor E2E.

### Modified Capabilities

Нет. Новый SQL Results использует существующие общие операции панелей.

## Impact

Общий forge.sql/protocol boundary и ide.sql result backend; существующие
LSP/Conform/Tasks key registration и common panel registry/controls. Новых
plugins нет, 67 pins/существующие backports сохраняются. Sqls 0.2.48 и sqruff
0.44.0 закрепляются после native probe; официальный sqls amd64, native source
build ARM64 с предоставленным Go >=1.25/C compiler. Всё явно, без SDK download
на старте. Windows temp/build/cache на F:. Ubuntu/Mac/GUI и внешние DB backends
без реального прогона не PASS.
