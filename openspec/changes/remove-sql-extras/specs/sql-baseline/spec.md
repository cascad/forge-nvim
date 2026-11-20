# Spec Delta

## ADDED Requirements

### Requirement: IDE-SQL-10 SQL baseline без собственных DB/test слоёв

Редактор SHALL сохранять подсветку SQL и upstream Sqruff LSP/formatter через
общие tools.json/PATH/Mason и прежние dialect настройки. Собственные DB
connections/schema/query/Results, SQL Neotest adapter, SQLS SDK/patch и Rust
SQL test runner SHALL отсутствовать в runtime и новой поставке. Пользовательские
БД/config/SDK MUST сохраняться. Открытие и save SQL MUST NOT устанавливать tools.

Платформы: все
Проверка: tests/e2e/sql-basic.test.lua, tests/install-profile.test.py,
tests/install-setup.test.py, tests/release-inventory.test.py.

#### Scenario: Обычный SQL
- **WHEN** пользователь открывает и форматирует SQL без БД
- **THEN** работают Sqruff diagnostics/format и явный tool path
- **AND** SQLS/test runner/Go/Rust ради SQL не запускаются

#### Scenario: Удалённая поверхность
- **WHEN** открывается SQL и общая панель Tests
- **THEN** нет SQLRun/SQLConnect/SQLStop, SQL Results component и SQL adapter
- **AND** обычные панели и редактирование остаются доступны

#### Scenario: Установка
- **WHEN** выбран SQL и выполнен setup/inventory
- **THEN** нужны Sqruff и grammar, дополнительные native SQL tools не готовятся
- **AND** старые явно переданные archives используют только общие archive checks
- **AND** пользовательские файлы/БД/установленные SDK не удаляются
