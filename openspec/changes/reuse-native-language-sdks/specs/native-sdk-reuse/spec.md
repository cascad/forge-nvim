# Spec Delta

## Purpose

Разделить приватное состояние редактора fride и штатные пользовательские SDK, сохранив выбранные пользователем toolchains, настройки и проектное окружение.

## ADDED Requirements

### Requirement: IDE-BOOT-17 Приватный IDE с обычными SDK

Установка и запуск fride SHALL изолировать компоненты IDE и сохранять штатное окружение Go/Rust/Node/npm/Python пользователя и проекта; они MUST NOT создавать отдельный SDK-профиль или устанавливать отсутствующий языковой SDK без выбора пользователя.
Платформы: все.
История: FIXLOG §244; заменяет ошибочную границу IDE-BOOT-16 / §243.
Проверка: tests/install-sdk-state.test.py; native macOS отдельно владельцем.

#### Scenario: Existing SDK context
- **GIVEN** пользователь задал SDK homes, configs, caches, prefixes, project build flags и PATH
- **WHEN** выполняются setup, probes или запуск установленного fride
- **THEN** SDK значения сохраняются, исходные SDK bin directories сохраняют порядок
- **AND** бинарь/config/logs принадлежат комплекту fride, а plugins/IDE tools/state/cache — штатному namespace NVIM_APPNAME=fride

#### Scenario: Active Python environment
- **GIVEN** в PATH активирована проектная venv
- **WHEN** Python запускается из fride
- **THEN** используется эта venv с исходным VIRTUAL_ENV и собственным sys.prefix

#### Scenario: No explicit SDK overrides
- **GIVEN** SDK variables не заданы
- **WHEN** пользователь запускает SDK из fride
- **THEN** fride не задаёт собственные homes/configs/prefixes SDK
- **AND** штатные пути SDK сохраняются, включая defaults, зависящие от XDG

#### Scenario: Upgrade from the mistaken isolated profile
- **GIVEN** в существующем комплекте остались sdk-state/config files от §243
- **WHEN** комплект обновляется и запускается
- **THEN** файлы сохраняются без переноса или удаления
- **AND** launcher больше не выбирает их вместо SDK пользователя
- **AND** прежние data/state/cache не удаляются; явный setup готовит приложение fride в стандартных каталогах

#### Scenario: Caller restoration
- **WHEN** Windows launcher завершился с ненулевым кодом
- **THEN** он возвращает код и восстанавливает изменённое окружение вызывающего процесса
