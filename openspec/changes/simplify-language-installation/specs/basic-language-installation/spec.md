# Spec Delta

## Purpose

Согласовать базовый языковой состав установщика с готовыми upstream tools,
не требуя дополнительных SQL DB/test bundles и Bash debug adapter.

## ADDED Requirements

### Requirement: IDE-BOOT-35 Базовый состав установки языков

Выбор SQL/Bash SHALL готовить подсветку и штатные LSP/format/lint tools без
обязательных sqls, SQLLogicTest, SQLite CLI или Bash DAP; native catalog MUST
требовать только Core и выбранный Terminal, сохраняя штатные SDK prerequisites.
Платформы: все. Проверка: tests/install-profile.test.py, tests/install-runtime.test.py.
Проверка: tests/install-setup.test.py, tests/release-inventory.test.py;
native macOS отдельно владельцем.

#### Scenario: SQL and Bash selected
- **WHEN** выбран базовый SQL/Bash
- **THEN** SQL содержит Sqruff, Bash — bash-language-server/shfmt/ShellCheck
- **AND** Bash использует обычный Node prerequisite, SQL не требует SDK/БД

#### Scenario: Core only artifact catalog
- **GIVEN** языки выбраны, Core опубликован, Terminal не выбран
- **WHEN** installer выбирает artifacts
- **THEN** не требуются языковые archives и дополнительные SQL/Bash assets
- **AND** обычные SDK checks и явный tools setup сохраняются

#### Scenario: Terminal missing
- **WHEN** Terminal выбран, но его archive отсутствует
- **THEN** installer останавливается до изменения прежнего комплекта

#### Scenario: Explicit additional SQL bundle
- **GIVEN** пользователь явно передал прежний bundle с дополнительными SQL tools
- **WHEN** выполняется установка
- **THEN** native composition и проверки его собственных tools сохраняются
- **AND** отсутствие такого bundle не мешает базовому SQL

#### Scenario: Inventory reflects actual delivery
- **WHEN** генерируется базовый publisher inventory
- **THEN** он учитывает Mason tools и Core/Terminal assets без вымышленных
  обязательных языковых archives или дополнительных native SQL tools
