# Spec Delta

## Purpose

Обеспечить воспроизводимый запуск Core acceptance из полного batch, с явными
подготовленными входами и честным разграничением source/installed проверок.

## ADDED Requirements

### Requirement: IDE-TEST-11 Входы Core acceptance в batch

Пакет проверок SHALL формировать обязательные Core acceptance аргументы и
проверять доступность объявленных входов до выполнения команд пакета.
Платформы: все. Проверка: tests/lib/test_batch.test.lua.

#### Scenario: Prepared Core inputs
- **WHEN** выбраны installed kit/profile или native source deps/runtime
- **THEN** suite получает соответствующие обязательные аргументы
- **AND** plan явно показывает installed-kit либо prepared-native-config mode

#### Scenario: Missing inputs
- **WHEN** Core acceptance входит в пакет, но обязательные входы отсутствуют
- **THEN** dry plan показывает missing_inputs и ready=false без запуска E2E
- **AND** actual batch завершается exit2 до любых тестов с неполным отчётом
- **AND** suite не исключается и входы не устанавливаются автоматически
