## Purpose

Запуск и отладка выбранного теста из редактора с понятным результатом и
выводом, в том числе для Rust Cargo workspace на всех целевых системах.

## ADDED Requirements

### Requirement: IDE-TEST-3 Rust nearest и file в workspace

Редактор SHALL запускать выбранный Rust тест или тесты выбранного файла
в Cargo workspace, показывать реальные pass/fail и output. Пробелы, Unicode
и системные разделители пути MUST сохранять семантику выбора.

Платформы: все
Проверка: tests/e2e/rust-language.test.lua (nextest nearest/file, integration)

#### Scenario: nearest и соседний fail
- **GIVEN** workspace с двумя crates, успешным тестом и соседним падающим
- **WHEN** пользователь нажимает Space T t в успешном тесте
- **THEN** запускается только этот тест, результат passed и вывод видны
- **AND** Space T f запускает оба теста файла с настоящими passed/failed

#### Scenario: integration test
- **WHEN** пользователь запускает nearest в integration test local crate
- **THEN** исполняется выбранный integration test, соседние тесты не выполняются
- **AND** результат и вывод доступны в Tests/Test Output

### Requirement: IDE-TEST-4 Rust debug nearest в workspace

Редактор SHALL собирать и отлаживать выбранный Rust тест через настоящий
debug adapter, останавливаться на breakpoint и сохранять результат/output.
Выбор executable MUST работать в workspace с несколькими test targets и
путём с пробелами/Unicode на целевых ОС.

Платформы: все
Проверка: tests/e2e/rust-language.test.lua (debug nearest)

#### Scenario: breakpoint, eval и continue
- **WHEN** пользователь ставит breakpoint в успешном Rust тесте и нажимает Space T d
- **THEN** тест останавливается на breakpoint, значение local доступно через eval
- **AND** после continue появляется настоящий результат/output, соседний fail не исполняется
- **AND** штатный launch не сообщает отсутствие program или No active session
