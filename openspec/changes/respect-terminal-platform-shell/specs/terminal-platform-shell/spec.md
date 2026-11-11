# Spec Delta

## Purpose

Интерактивный Terminal сохраняет shell целевой системы; установка optional
PowerShell на POSIX не меняет выбранную оболочку редактора.

## ADDED Requirements

### Requirement: IDE-PANEL-19 Shell managed Terminal зависит от платформы

На POSIX managed Terminal SHALL использовать выбранный при старте vim.o.shell
независимо от наличия pwsh. На Windows он SHALL сохранять предпочтение
pwsh -NoLogo при доступном executable pwsh и fallback к vim.o.shell без него.
Выбор SHALL оставаться локальным для Terminal; глобальные shell options,
существующий job, buffer/channel/PID и история MUST NOT меняться из-за
скрытия/повторного показа панели. После повторного показа shell SHALL
выполнять следующую пользовательскую команду.

Платформы: все.
Проверка: tests/e2e/terminal-shell.test.lua (native POSIX/Windows branches).

#### Scenario: Optional PowerShell на POSIX
- **GIVEN** выбран настоящий POSIX shell и в PATH дополнительно есть pwsh
- **WHEN** пользователь открывает Terminal и выполняет команду
- **THEN** выбранный shell выполняет её, pwsh не запускается
- **AND** q и Space w T сохраняют job/output, следующая команда выполняется

#### Scenario: POSIX без PowerShell
- **GIVEN** pwsh отсутствует в private PATH
- **WHEN** пользователь открывает Terminal
- **THEN** vim.o.shell реально выполняет команды и переживает hide/reopen

#### Scenario: Windows с PowerShell
- **GIVEN** executable pwsh доступен
- **WHEN** пользователь открывает Terminal
- **THEN** интерактивный pwsh -NoLogo реально выполняет команды
- **AND** глобальный shell редактора не меняется

#### Scenario: Windows без PowerShell
- **GIVEN** pwsh отсутствует, vim.o.shell доступен
- **WHEN** пользователь открывает Terminal
- **THEN** fallback реально выполняет команды и сохраняется после hide/reopen
