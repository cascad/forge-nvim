# Spec Delta

## Purpose

Позволить выбирать существующие языковые среды и IDE tools через настройки
пользователя и проекта, сохраняя штатные способы обнаружения и общие логи.

## ADDED Requirements

### Requirement: IDE-BOOT-33 Настройка путей Python Node Bash

fride SHALL применять декларативные пути Python, Node, native Bash, Bats и JS
entrypoints tools/adapters из настроек проекта перед пользовательскими
настройками и прежними vim.g/env overrides; при отсутствии override MUST
сохранять штатное обнаружение соответствующей интеграции.
Платформы: все.
Проверка: tests/e2e/tool-paths.test.lua; native macOS отдельно владельцем.

#### Scenario: Project override and relative path
- **GIVEN** user tools.json задаёт инструмент, а .fride/tools.json проекта задаёт другой
- **WHEN** пользователь запускает соответствующий workflow
- **THEN** используется проектный путь относительно корня этого проекта
- **AND** пробелы в пути не изменяют границы argv

#### Scenario: Legacy and native environment
- **GIVEN** новых overrides нет
- **WHEN** выбирается инструмент
- **THEN** работают прежние vim.g/env overrides и native project discovery
- **AND** активная Python venv и выбранное окружение SDK не меняются

#### Scenario: Invalid explicit selection
- **GIVEN** выбранный config повреждён или явный путь неверен
- **WHEN** запрашивается инструмент
- **THEN** пользователь получает ошибку с источником настройки
- **AND** другая копия инструмента не используется молча

#### Scenario: Adapter entrypoint
- **GIVEN** настройка указывает на существующий JS-файл адаптера
- **WHEN** строится DAP command
- **THEN** файл используется как entrypoint выбранного Node, без требования executable bit у JS

#### Scenario: Inspect selection
- **WHEN** пользователь вызывает ForgeToolPaths
- **THEN** общие логи показывают выбранные пути, источник и ошибки текущего проекта
- **AND** отчёт и обычное открытие проекта ничего не устанавливают

#### Scenario: Switch project and edit config
- **WHEN** пользователь меняет проект или сохраняет tools.json
- **THEN** последующий выбор использует настройки соответствующего проекта и актуальное содержимое
