# Spec Delta

## Purpose

Позволить запустить доставку nvim_forge удалённой командой, автоматически
получив полный source и передав управление установщику целевой ОС.

## ADDED Requirements

### Requirement: IDE-BOOT-8 Удалённый bootstrap без предварительного Git

Входной скрипт SHALL получать source по HTTP(S), проверять его структуру
и запускать платформенный installer с локальным source без предварительного
clone пользователем. Одинаковый архив SHALL переиспользовать source directory.
Неуспешная доставка или отказ backend SHALL возвращать ненулевой exit,
не объявляя установку успешной и не запуская installer из неполного source.

Платформы: все. История: FIXLOG §232.
Проверка: tests/install-bootstrap.test.py; macOS отдельно на Mac.

#### Scenario: Первая доставка и повтор

- **GIVEN** source ещё не получен, shell и downloader доступны
- **WHEN** пользователь исполняет скачанный entry script
- **THEN** архив извлечён, запущен installer нужной ОС с local-source mode
- **AND** повтор того же архива использует то же source directory

#### Scenario: Сбой загрузки или структуры

- **WHEN** источник недоступен либо архив не содержит profile/platform installer
- **THEN** backend не вызывается, entry завершается с ненулевым кодом
- **AND** временная доставка не остаётся готовым source

#### Scenario: Ошибка платформенной установки

- **WHEN** вызванный installer завершается с ненулевым кодом
- **THEN** entry тоже завершается с ненулевым кодом
- **AND** полученный source доступен для диагностики/повторного запуска
