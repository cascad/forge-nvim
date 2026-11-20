# Spec Delta

## MODIFIED Requirements

### Requirement: IDE-BOOT-35 Базовый состав установки языков

Выбор SQL/Bash SHALL готовить подсветку и upstream LSP/format/lint tools без
SQLS, SQLLogicTest, SQLite CLI и обязательного Bash DAP. Native catalog MUST
требовать только Core и выбранный Terminal, сохраняя штатные SDK prerequisites.

Платформы: все
Проверка: tests/install-profile.test.py, tests/install-runtime.test.py,
tests/install-setup.test.py, tests/release-inventory.test.py.

#### Scenario: SQL and Bash selected
- **WHEN** выбран базовый SQL/Bash
- **THEN** SQL содержит Sqruff, Bash — bash-language-server/shfmt/ShellCheck
- **AND** Bash использует Node prerequisite, SQL не требует SDK/БД

#### Scenario: Core only artifact catalog
- **GIVEN** языки выбраны, Core опубликован, Terminal не выбран
- **WHEN** installer выбирает artifacts
- **THEN** языковые archives и дополнительные SQL/Bash assets не обязательны
- **AND** общие SDK checks и явный tools setup сохраняются

#### Scenario: Terminal missing
- **WHEN** выбранный Terminal archive отсутствует
- **THEN** installer останавливается до изменения прежнего комплекта

#### Scenario: Explicit additional SQL bundle
- **GIVEN** явно передан прежний language archive
- **WHEN** выполняется установка
- **THEN** действуют только общие archive integrity checks
- **AND** специальные SQL tools не выбираются и не проверяются, отсутствие archive не мешает Sqruff

#### Scenario: Inventory reflects actual delivery
- **WHEN** генерируется publisher inventory
- **THEN** учитываются Mason tools/Core/Terminal и явно переданные общие archives
- **AND** SQL-specific native SDK/tools больше не перечисляются
