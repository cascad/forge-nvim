# Spec Delta

## Purpose

Согласовать installer SDK readiness с сохранённым пользовательским выбором fride,
используя verified Core и общие правила путей при чистой установке без Neovim.

## ADDED Requirements

### Requirement: IDE-BOOT-40 Общий preflight через Core

Установщик SHALL получить и проверить Core перед language SDK preflight и
использовать общие fride user-scope SDK resolvers без загрузки user init/plugins.
Платформы: все. Проверка: tests/install-sdk-settings.test.py; Mac отдельно.

#### Scenario: Core before SDK
- **WHEN** выполняется actual installation либо SDK readiness check
- **THEN** Core получается из explicit inputs/catalog и проверяется до SDK lookup
- **AND** Core может скачаться при missing SDK, но target и другие компоненты не заменяются
- **AND** готовый Core повторно используется при дальнейшей установке

#### Scenario: Saved SDK choice
- **WHEN** в user sdk.json/tools.json выбран существующий Go/Rust/Python/Node
- **THEN** preflight проверяет этот выбор и показывает source/path/version
- **AND** private setup использует те же user-scope semantics
- **AND** project config директории запуска не переопределяет установку

#### Scenario: Invalid explicit choice
- **WHEN** saved path/JSON повреждён либо SDK unavailable
- **THEN** report содержит причину и источник, без скрытого PATH substitution
- **AND** SDK не устанавливается автоматически и прежний kit остаётся прежним

#### Scenario: Preview and native boundaries
- **WHEN** выбран preview/print-plan либо native Git readiness
- **THEN** Core не скачивается ради этого действия
- **AND** SDK homes/config/auth и system PATH не переписываются
