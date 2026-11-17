# Spec Delta

## Purpose

Дать SQL файлам обычные языковые возможности на готовом upstream сервере и
форматтере, без обязательного подключения к базе или собственного SQL backend.

## ADDED Requirements

### Requirement: IDE-BOOT-34 SQL на штатном Sqruff LSP

Обычное открытие SQL файла SHALL использовать готовый Sqruff LSP и formatter,
не требуя .sqls.json, подключения БД или запуска sqls/SQLLogicTest; путь sqruff
MUST учитывать общий контракт user/project overrides и показываться в логах.
Платформы: все. Проверка: tests/e2e/sql-basic.test.lua; native Mac отдельно.

#### Scenario: SQL without a database
- **GIVEN** Sqruff подготовлен, а подключения БД нет
- **WHEN** открывается SQL файл
- **THEN** присоединяется sqruff LSP, работает готовый formatter
- **AND** sqls, SQLLogicTest, Go и Rust не запускаются ради SQL

#### Scenario: Project settings
- **GIVEN** в tools.json проекта указан sqruff и в .sqruff заданы правила
- **WHEN** файл анализируется и форматируется
- **THEN** используются выбранный binary и штатные правила проекта

#### Scenario: Explicit advanced database operation
- **WHEN** пользователь явно запускает прежнюю SQL операцию с БД
- **THEN** прежняя интеграция подготавливается по запросу с её prerequisites
- **AND** обычное открытие SQL файла само её не активирует

#### Scenario: Invalid path
- **GIVEN** задан неверный explicit sqruff path
- **WHEN** пользователь запрашивает языковой инструмент
- **THEN** появляется ошибка настройки без скрытого fallback
