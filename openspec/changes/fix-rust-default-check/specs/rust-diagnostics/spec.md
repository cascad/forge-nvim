# Spec Delta

## Purpose

Базовая проверка Rust использует установленный compiler/Cargo без обязательного
Clippy и показывает настоящие compiler diagnostics в обычном UI редактора.

## ADDED Requirements

### Requirement: IDE-RUST-1 Компиляторная диагностика без Clippy

Редактор SHALL использовать штатный cargo check rust-analyzer для фоновой
проверки Rust на save без Clippy-specific аргументов. Отсутствие cargo-clippy
MUST NOT отключать compiler diagnostics. Сохранение исправленного файла SHALL
обновлять диагностику; открытие файла MUST NOT устанавливать tools.
Платформы: все
Проверка: tests/e2e/rust-language.test.lua (IDE-RUST-1)

#### Scenario: Clippy отсутствует
- **GIVEN** доступны настоящий Cargo/compiler/rust-analyzer, cargo clippy недоступен
- **WHEN** открыт Rust-файл с compiler error и он сохранён
- **THEN** ошибка rustc видна в diagnostic UI без установки Clippy

#### Scenario: Исправление файла
- **GIVEN** compiler diagnostic показана редактором
- **WHEN** пользователь исправляет код и сохраняет файл
- **THEN** устаревшая compiler diagnostic удаляется
- **AND** backend и инструменты не устанавливаются автоматически
