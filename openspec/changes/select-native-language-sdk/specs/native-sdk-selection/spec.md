# Spec Delta

## Purpose

Позволить выбрать существующий Go/Rust SDK для проекта, в том числе вручную,
сохраняя штатное окружение языков и единый выбор во всех workflow редактора.

## ADDED Requirements

### Requirement: IDE-BOOT-37 Выбор установленного SDK проекта

fride SHALL предоставлять выбор обнаруженного Go/Rust SDK, ручной путь и
режим «Авто» с user/project сохранением, видимыми executable/версией/источником.
Платформы: все. Проверка: tests/e2e/sdk-selection.test.lua; native Mac отдельно.

#### Scenario: Discover installed SDKs
- **WHEN** пользователь открывает выбор SDK или обновляет список
- **THEN** discovery выполняется асинхронно и показывает проверенные установки
- **AND** неполная Go wrapper installation не объявляется установленным SDK
- **AND** список и проверки не загружают отсутствующий toolchain

#### Scenario: Manual and scoped choice
- **WHEN** выбран SDK из списка или введён существующий executable/root
- **THEN** после проверки выбор сохраняется в user/project scope
- **AND** project choice имеет приоритет; project «Авто» может отменить user choice
- **AND** invalid path/cancel не подменяют SDK и не портят прежние настройки

#### Scenario: Reopen and native workflows
- **WHEN** пользователь явно применяет сохранённый SDK
- **THEN** проект переоткрывается с сохранением сессии в выбранной native среде
- **AND** LSP/run/debug/tests наследуют выбранный SDK через обычные механизмы
- **AND** активные debug/tests/tasks/terminal не прерываются молча

#### Scenario: Auto and project switch
- **GIVEN** SDK выбран в одном проекте
- **WHEN** открыт другой проект или выбран «Авто»
- **THEN** используется настройка нового проекта либо исходное окружение
- **AND** выбор другого проекта не протекает в «Авто»

#### Scenario: Passive startup and boundaries
- **WHEN** редактор стартует или читает сохранённый SDK
- **THEN** это не вызывает discovery/version CLI/downloads
- **AND** явный путь проверяется без скрытого fallback
- **AND** global PATH/profiles, SDK homes/installations и package manager configs не меняются
