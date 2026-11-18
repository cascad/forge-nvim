# Spec Delta

## Purpose

Согласовать сохранённый выбор Python/Node с подготовкой инструментов IDE,
используя обычную среду штатных providers без изменения установок SDK.

## ADDED Requirements

### Requirement: IDE-BOOT-39 Выбранный SDK при явном tools setup

fride SHALL передавать explicit Python/Node выбор нужных компонентов в среду
tools setup до инициализации менеджера IDE tools.
Платформы: все. Проверка: tests/e2e/setup-sdk-paths.test.lua; Mac отдельно.

#### Scenario: Prepare selected native SDK
- **WHEN** выполняется явный tools setup с сохранённым Python/Node путём
- **THEN** штатные команды SDK доступны из выбранного каталога
- **AND** report содержит путь и источник выбора
- **AND** SDK homes/system PATH/обычный runtime не меняются

#### Scenario: Refuse unsupported or broken selection
- **WHEN** выбранный executable не представим штатными командами provider либо npm отсутствует в выбранном Node SDK
- **THEN** setup останавливается до установки tools с понятным источником ошибки
- **AND** другая установленная копия не подставляется скрыто

#### Scenario: Preserve unrelated profiles
- **WHEN** override отсутствует либо язык не нужен выбранным компонентам
- **THEN** соответствующий SDK setup не переопределяет
- **AND** обычный старт не выполняет новую подготовку или version CLI
