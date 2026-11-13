# Spec Delta

## Purpose

Позволить штатно отключить настроенный Rust LSP без его возврата фоновой
подготовкой проекта и включить его обратно обычными средствами Neovim.

## ADDED Requirements

### Requirement: IDE-RUST-3 Подготовка Rust уважает native enabled state

Ранняя подготовка Cargo workspace SHALL подчиняться native enabled state
настроенного rust_analyzer. При выключенном сервере SHALL не начинаться
автоматические metadata/LSP процессы; выключение до доставки уже запрошенного
metadata ответа SHALL не запускать клиента. Повторное native enable SHALL
сохранять обычный запуск на открытом Rust файле.

Платформы: все. История: FIXLOG §230.
Проверка: tests/e2e/rust-language.test.lua (IDE-RUST-3, IDE-RUST-2).

#### Scenario: Сервер отключён до выбора проекта

- **GIVEN** LSP конфигурация загружена, rust_analyzer отключён через vim.lsp.enable
- **WHEN** пользователь выбирает Cargo project и открывает Rust файл
- **THEN** warmup не запускает metadata, Rust клиент не появляется
- **AND** повторное enable штатно запускает клиент для открытого файла

#### Scenario: Выключение при ожидающем ответе

- **WHEN** Cargo metadata уже запрошена и пользователь выключает rust_analyzer
- **THEN** поздняя доставка настоящего ответа не запускает LSP
- **AND** глобальный native enabled state остаётся false

#### Scenario: Обычный enabled workflow

- **WHEN** rust_analyzer включён
- **THEN** сохраняются ранний workspace/reuse и язык по IDE-RUST-2/1
