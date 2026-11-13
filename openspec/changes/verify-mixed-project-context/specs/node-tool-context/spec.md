## Purpose

Готовые Node-based language tools находятся в правильном проектном каталоге
при запуске из файла и при передаче уже выбранного language root.

## ADDED Requirements

### Requirement: IDE-NODE-5 Каталог поиска Node tools
Поиск Node tools SHALL сохранять переданный существующий каталог как fallback
root, если package.json не найден. Для файла fallback SHALL оставаться его
родительским каталогом. Project-local tools MUST иметь приоритет над shared
tools независимо от наличия package.json в корне выбранного repo.
Платформы: все.
Проверка: tests/e2e/mixed-project.test.lua, tests/e2e/node-language.test.lua,
tests/e2e/bash-language.test.lua.

#### Scenario: Bash LSP в смешанном repo
- **GIVEN** Git root без package.json с локальным Bash LSP в node_modules и JS package во вложенном web
- **WHEN** открыт Bash script и backend запускается с уже выбранным Git root
- **THEN** запускается локальный Bash LSP из этого root
- **AND** JS package использует свои tools, cwd IDE остаётся корнем repo

#### Scenario: Обычный файл Node package
- **GIVEN** текущий JS файл находится в package с package.json
- **WHEN** запускается файл или выбирается package script
- **THEN** используется ближайший package root с обычными argv/cwd/output
