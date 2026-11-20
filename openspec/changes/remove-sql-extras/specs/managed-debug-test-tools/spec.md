# Spec Delta

## MODIFIED Requirements

### Requirement: IDE-BOOT-23 Подготовка существующих debug/test tools

Managed setup SHALL готовить pinned codelldb1.12.2 через Mason и применять существующий
hash-checked Bash adapter patch только к принадлежащему fride package.
Ошибка/неизвестный payload MUST давать nonzero и сохранять исходник.
SDK/чужие adapters MUST не изменяться, startup MUST не устанавливать/патчить tools.
SQL SHALL использовать базовый upstream Sqruff без SQLS/test runner bundle.
Native Mac/publication SHALL оставаться непроверенными до фактического прогона.

Платформы: все
Проверка: tests/install-debug-tools.test.py, tests/e2e/sql-basic.test.lua.

#### Scenario: Подготовка и повтор
- **WHEN** выбран Rust/Bash и выполнен tools setup
- **THEN** debugger доступен из Mason, Bash payload подготовлен без ручной команды
- **AND** повтор сохраняет готовые файлы

#### Scenario: Неизвестный Bash payload
- **WHEN** adapter не соответствует принятому hash
- **THEN** setup завершается nonzero, исходник и чужие adapters сохраняются

#### Scenario: SQL без SDK компилятора
- **WHEN** выбран SQL без Go/Rust
- **THEN** готовятся Sqruff/grammar без SQLS/SQL test runner и compiler SDK

#### Scenario: Неполная поставка
- **WHEN** обязательный Core/Terminal artifact неполон или manifest/hash не совпал
- **THEN** общая проверка отклоняет поставку и сохраняет прежний kit
- **AND** SQL-specific native version/readiness probes не выполняются
