## Purpose

Сохранить быстрый анализ обычного Lua проекта, не заставляя языковой сервер заранее обходить все библиотеки установленной IDE и не подменяя настройки самого проекта.

## ADDED Requirements

### Requirement: IDE-BOOT-31 Ограниченная автоматическая Lua library

Конфигурация существующего Lua language server SHALL не добавлять весь runtimepath/plugins в workspace.library. Если в корне проекта есть .luarc.json либо .luarc.jsonc, IDE SHALL не добавлять собственную library; при отсутствии этих файлов default library SHALL содержать только текущий Neovim runtime для его API. Настройки проекта и SDK/pins MUST сохраняться. Native consumer маленького Lua проекта SHALL получать type diagnostic и его очистку после edit/save в прежнем20s diagnostic deadline и сохранять правку после перезапуска.

Платформы: windows, linux/ubuntu, macos; native Mac gate отдельно.
Проверка: tests/install-core-acceptance.test.py, FIXLOG §261.

#### Scenario: Явная конфигурация проекта
- **WHEN** открывается Lua проект с .luarc.json либо .luarc.jsonc
- **THEN** IDE не навязывает свою library и не обходит plugins как библиотеки проекта
- **AND** project config сохранён

#### Scenario: Конфигурация по умолчанию
- **WHEN** Lua проект не содержит .luarc.json/jsonc
- **THEN** automatic library содержит только Neovim runtime без plugin directories
- **AND** Neovim API остаётся доступен серверу

#### Scenario: Диагностика и повторный запуск
- **WHEN** пользователь открывает небольшой Lua файл с type mismatch, исправляет и сохраняет его
- **THEN** native diagnostic приходит в прежнем deadline и исчезает после исправления
- **AND** повторное открытие редактора показывает сохранённый файл
