# Spec Delta

## Purpose

Показывать готовность штатных языковых SDK отдельно от приватных компонентов IDE и останавливать установку до скрытого скачивания отсутствующего языка.

## ADDED Requirements

### Requirement: IDE-BOOT-18 Штатные SDK как явные prerequisites

Установщик SHALL отделять native SDK prerequisites от IDE artifacts и пассивно проверять требуемые SDK перед подготовкой компонентов; проверка MUST NOT устанавливать SDK или запускать автоматическое скачивание toolchain.
Платформы: все.
История: FIXLOG §246.
Проверка: tests/install-prerequisites.test.py и tests/install-runtime.test.py; native Mac отдельно.

#### Scenario: Existing SDK
- **GIVEN** выбранному компоненту нужен установленный SDK
- **WHEN** выполняется preflight
- **THEN** report содержит его путь, version/status
- **AND** SDK используется из PATH, отсутствует в списке скачиваемых IDE parts

#### Scenario: Missing or broken SDK
- **WHEN** SDK отсутствует, не отвечает, завершается ошибкой или возвращает неподходящий version output
- **THEN** preflight сообщает missing/unavailable с причиной и log
- **AND** SDK/IDE artifacts не скачиваются, target и прежний kit не меняются

#### Scenario: Explicit check and preview
- **WHEN** вызван --check-sdks
- **THEN** выводится JSON, nonready даёт exit2, backend не запускается
- **AND** --preview/--print-plan сами по себе SDK не запускают

#### Scenario: SDK archive offered as IDE part
- **WHEN** catalog/part объявлен как node-runtime или go-runtime
- **THEN** он отклоняется как языковой SDK, а не часть IDE

#### Scenario: Installer toolchain isolation
- **WHEN** installer проверяет SDK или готовит IDE tools
- **THEN** Go/Rustup auto-download toolchains отключён в этом subprocess
- **AND** обычный запуск fride сохраняет SDK окружение пользователя по IDE-BOOT-17
