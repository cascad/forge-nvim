## ADDED Requirements

### Requirement: IDE-BOOT-49 Штатный cargo-nextest для Rust Tests

Выбранный Rust комплект SHALL проверять готовый cargo-nextest до публикации
готовности. Установщик SHALL переиспользовать существующую версию, предлагать
existing/install/skip/refresh/cancel и официальный upstream install в обычный
CARGO_HOME/bin. User/project ручной path SHALL применяться к native Tests;
явная ошибка MUST оставаться видимой без fallback. Обычный startup MUST NOT
устанавливать tools или выполнять version discovery.
Платформы: все.
Проверка: tests/e2e/rust-test-runtime.test.lua.

#### Scenario: Установленный nextest

- **GIVEN** пользователь уже установил nextest или выбрал готовый executable
- **WHEN** повторно устанавливается fride или запускаются Rust Tests
- **THEN** используется этот tool, его версия/файлы не заменяются
- **AND** язык SDK, Cargo home и global PATH не переписываются

#### Scenario: Отсутствующий nextest

- **WHEN** выбран Rust, nextest отсутствует
- **THEN** интерактивный setup предлагает действие с командой/источником/каталогом
- **AND** install выполняется только после выбора; skip снимает Rust компоненты
- **AND** без TTY/выбора готовность не публикуется, прежний kit остаётся

#### Scenario: Явная ошибка

- **WHEN** задан неверный cargo-nextest path либо существующий target повреждён
- **THEN** причина показана, другой tool не выбирается и файл не перезаписывается
- **AND** редактор остаётся доступен, диагностика есть в общих Logs
