## Purpose

Автоматически доставлять выбранные части приватного SDK на нужную платформу, чтобы пользователь не готовил RuntimePath и не скачивал инструменты снятых компонентов Custom.

## ADDED Requirements

### Requirement: IDE-BOOT-14 Доставка выбранного модульного SDK

Без explicit runtime система SHALL находить Core и каждый selected component/dependency по platform catalog, проверять SHA каждого архива и собирать общий private runtime. Она MUST не подхватывать системный Neovim/пакеты. Каждый модуль SHALL иметь проверяемые platform/component/files/paths/probes; несовпадение, лишние файлы или конфликт путей MUST останавливать установку до изменения готового комплекта. Explicit full-runtime API SHALL сохраняться.
Платформы: windows, linux/ubuntu, macos (native acceptance отдельно).
Проверка: tests/install-runtime.test.py, legacy isolation/UI controls.

#### Scenario: Custom и общая зависимость
- **WHEN** выбран компонент с общей runtime dependency
- **THEN** скачиваются только Core, выбранные компоненты и dependency closure
- **AND** установленный launcher видит executable выбранного модуля в своём runtime
- **AND** чужие config/SDK остаются неизменными

#### Scenario: Каталог и отказ до установки
- **WHEN** отсутствует native artifact или catalog содержит дубликат/невалидные поля
- **THEN** установка даёт конкретный nonzero отказ без запуска backend/изменения target

#### Scenario: Ошибка архива или модуля
- **WHEN** SHA/manifest/platform/component/файлы не соответствуют ожидаемому либо модули конфликтуют
- **THEN** установка завершается nonzero и сохраняет диагностику
- **AND** существующий готовый комплект продолжает запускаться

#### Scenario: Повтор и явный runtime
- **WHEN** установка повторяется с проверенным cache или задан explicit runtime
- **THEN** выбор компонентов и запуск сохраняют прежний private install контракт
- **AND** explicit runtime не требует module catalog
