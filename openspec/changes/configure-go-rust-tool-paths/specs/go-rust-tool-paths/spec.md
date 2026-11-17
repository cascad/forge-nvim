# Spec Delta

## Purpose

Выбирать существующие Go/Rust IDE tools из общих настроек пользователя и проекта,
сохраняя штатные SDK, native workspace roots и существующие интеграции редактора.

## ADDED Requirements

### Requirement: IDE-BOOT-36 Пути Go и Rust IDE tools

fride SHALL применять tools.json к gopls, rust-analyzer, gofumpt, golines,
rustfmt, dlv и codelldb по общему приоритету project/user/legacy/native;
неверный explicit executable MUST давать ошибку без скрытой подмены.
Платформы: все. Проверка: tests/e2e/go-rust-paths.test.lua, native Mac отдельно.

#### Scenario: LSP per workspace
- **GIVEN** сервер указан в tools.json проекта и отсутствует в PATH
- **WHEN** открывается Go/Rust файл
- **THEN** запускается выбранный сервер с native root, env и аргументами
- **AND** go.work/Cargo workspace обнаруживается прежним способом

#### Scenario: Formatter context
- **WHEN** форматируется файл фонового проекта
- **THEN** выбирается его formatter, а не настройка текущей панели

#### Scenario: Debug override
- **GIVEN** в проекте выбран dlv или codelldb
- **WHEN** запускается DAP
- **THEN** используется этот executable, стандартный DAP template не меняется
- **AND** неверный dlv не заменяется более новой копией из PATH

#### Scenario: Native fallback and passive report
- **GIVEN** override не задан
- **WHEN** используется инструмент или открыт ForgeToolPaths
- **THEN** существующий поиск сохраняется, в логах видны путь/источник
- **AND** пассивный отчёт не вызывает SDK/version probes или установки
