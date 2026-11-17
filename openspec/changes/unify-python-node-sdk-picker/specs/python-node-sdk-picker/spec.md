# Spec Delta

## Purpose

Позволить выбирать существующие Python и Node среды через общее меню SDK,
сохраняя штатные правила проекта и единственный источник настройки tools.json.

## ADDED Requirements

### Requirement: IDE-BOOT-38 Единый выбор Python и Node

fride SHALL предоставлять Python/Node через общий вход выбора SDK с проверенной
версией, executable, источником и user/project областью настройки.
Платформы: все. Проверка: tests/e2e/python-node-sdk-picker.test.lua; Mac отдельно.

#### Scenario: Discover and select
- **WHEN** пользователь открывает Python/Node SDK menu или refresh
- **THEN** версии проверяются асинхронно только по этому запросу
- **AND** можно выбрать доступную среду либо ввести executable/root вручную
- **AND** выбор сохраняется в существующий tools.json соответствующей области

#### Scenario: Reset and compatibility
- **WHEN** выбор в области сброшен
- **THEN** удаляется только её ключ языка и действуют прежние правила наследования
- **AND** project/user/legacy priority, Python venv и Node project tools сохраняются
- **AND** соседние keys/metadata tools.json и Go/Rust settings не теряются

#### Scenario: Invalid or cancelled selection
- **WHEN** введён неверный путь, JSON повреждён или выбор отменён
- **THEN** прежняя конфигурация не перезаписывается неверным выбором
- **AND** ошибка содержит источник и не вызывает скрытую замену SDK

#### Scenario: Apply and boundaries
- **WHEN** пользователь сохраняет выбор
- **THEN** следующие запуски workflow используют существующие языковые резолверы
- **AND** можно явно переоткрыть проект с сессией для обновления работающих LSP
- **AND** активные debug/tests/tasks/terminal не прерываются при SDK apply
- **AND** global PATH/profiles/SDK homes/installations не меняются, SDK не скачиваются

#### Scenario: Passive startup
- **WHEN** редактор запускается без открытия SDK menu
- **THEN** новый provider не запускает discovery/version CLI или установки
