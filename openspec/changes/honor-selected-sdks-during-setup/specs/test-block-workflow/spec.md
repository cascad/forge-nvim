# Spec Delta

## Purpose

Дать запускать проверки законченного блока одной командой и явно видеть состав
полного регресса, включая ранее отдельные native installer Python suites.

## ADDED Requirements

### Requirement: IDE-TEST-10 Пакет проверок цельного изменения

Репозиторий SHALL предоставлять Windows/POSIX команды выбора тестовых файлов,
просмотра плана и отдельного полного regression с native installer suites.
Платформы: все. Проверка: tests/e2e/test-batch.test.lua и batch этого change.

#### Scenario: Select a block
- **WHEN** передан список зарегистрированных tests или native installer suites
- **THEN** выполняются только выбранные файлы с сохранением exit/log/time
- **AND** неизвестный или повторённый путь отклоняется до запуска E2E
- **AND** inherited case filters не превращают полный файл в частичную проверку

#### Scenario: Review and run regression
- **WHEN** выбран plan либо regression
- **THEN** plan показывает состав без выполнения E2E
- **AND** regression включает полный registry для ОС и native installer Python suites
- **AND** ошибки не маскируются; timeout прекращает дальнейшие запуски
