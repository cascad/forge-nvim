## ADDED Requirements

### Requirement: IDE-BOOT-48 Штатные entrypoints готовых managed tools

Python LSP SHALL использовать выбранный Node и настоящий Pyright JS entrypoint,
сохраняя native roots/settings/Python selection. Native consumers SHALL получать
actual executable за Windows Mason batch export, когда нужен прямой process API.
Явные пользовательские paths MUST сохранять приоритет без wrapper substitution.
Платформы: все.
Проверка: tests/e2e/managed-entrypoints.test.lua.

#### Scenario: Выбранный Node без PATH

- **GIVEN** Node выбран в user/project settings, обычный PATH его не содержит
- **WHEN** открывается Python файл с готовым Pyright
- **THEN** LSP запускается этим Node, публикует diagnostics и Python choice прежний
- **AND** invalid Node/entrypoint оставляет editing с причиной в Logs без fallback

#### Scenario: Windows managed export

- **GIVEN** Mason export .cmd с native .exe в receipt
- **WHEN** BashLS/formatter/SQL server требует direct executable
- **THEN** используется этот готовый native target без запуска batch wrapper
- **AND** registry/package/files/SDK не изменяются и install не запускается

#### Scenario: Обычная среда

- **WHEN** выбран внешний executable/wrapper либо используется Linux/macOS
- **THEN** прежний explicit/PATH lookup остаётся
- **AND** Bash/SQL используют готовые upstream tools без дополнительных сервисов
