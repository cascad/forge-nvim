# Spec Delta

## ADDED Requirements

### Requirement: IDE-BOOT-7 Готовность общего оформления до первого файла

Редактор SHALL подготовить общие comments, indent guides, word highlights,
breadcrumbs, overview ruler и search lens на штатном VeryLazy до первого
ручного открытия файла. Эти функции SHALL сохраняться; первый файл MUST NOT
запускать их суммарную холодную загрузку на BufReadPost. UI responsiveness
SHALL проверяться native input/open отдельно от времени Cargo preparation.
Платформы: все
Проверка: tests/e2e/rust-language.test.lua (IDE-BOOT-7, вместе с IDE-RUST-2)

#### Scenario: Первый файл во время фоновой подготовки
- **GIVEN** штатный старт завершён и native Cargo занят build script
- **WHEN** пользователь впервые открывает обычный файл и затем Rust-файл
- **THEN** общие UI plugins уже подготовлены, ввод/открытие не ждут build script
- **AND** обе операции в reference E2E укладываются в300ms, raw времена сохраняются
