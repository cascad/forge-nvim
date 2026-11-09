# Proposal

## Why

IDE-062: SQL edit/query готов, но SQL-файлы не имеют настоящего test workflow
в общей панели Neotest. Успешный SELECT в Results не проверяет ожидаемые
данные и не заменяет тесты с результатом passed/failed и причиной ошибки.

## What Changes

- SQLLogicTest `.slt`: nearest/file/all через существующие Tests hotkeys,
  Test Output, переход к ошибке, rerun и stop без DAP.
- Переносимый native SQLite runner на официальной библиотеке sqllogictest;
  отдельная временная БД для каждого script, без подключения к рабочей БД.
- Unit исполнения — полный `.slt` файл: statements и assertions одного
  script разделяют состояние. Nearest не вырывает зависимый query из setup.
- Явная подготовка фиксированного SDK; открытие редактора/test discovery
  ничего не устанавливает. Missing runner даёт понятное сообщение.
- Реальные UI E2E, история причины/решений и команды на всех целевых ОС.
  Semantic references IDE-062 остаются отдельной незавершённой частью.

## Capabilities

### New Capabilities

- `sql-workflow`: IDE-SQL-7 — native SQLLogicTest/SQLite в Tests с реальными
  проверками ожидаемых данных, независимыми scripts и сохранённым output.
  Путь согласован с предыдущими SQL changes; в main inventory SQL ещё нет.

### Modified Capabilities

Нет изменений требований main specs; каталог содержит WezTerm/mac installer.

## Impact

Neotest adapter/registration, filetype `.slt`, source SDK и explicit preparation,
SQL fixtures/UI suite/runner registry, container build recipe и документация.
Новых Neovim plugins и startup installs нет. Windows/macOS/Ubuntu используют
одинаковый runner protocol; SQLite — первый test backend, не декларация
готовности PostgreSQL/MySQL/procedural DAP или semantic references.
