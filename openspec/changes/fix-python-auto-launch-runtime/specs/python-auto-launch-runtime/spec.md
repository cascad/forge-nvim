## Purpose

Сделать обычный запуск Python файла без окружения проекта предсказуемым и
давать раннюю неблокирующую диагностику, если выбранный SDK не запускается.

## ADDED Requirements

### Requirement: IDE-PY-3 Auto Python и готовность Current File
В режиме Auto fride SHALL предпочитать python перед python3 на Windows,
сохраняя приоритет explicit SDK/active и project venv и прежний POSIX порядок.
Current Python file SHALL асинхронно проверить выбранный SDK перед запуском
adapter; непригодный SDK MUST отменять запуск с коротким уведомлением и полной
причиной в общих Logs, без замены SDK, установки и modal Press ENTER.
Платформы: все
История: FIXLOG §302
Проверка: tests/e2e/python-auto-runtime.test.lua

#### Scenario: Обычный файл с конкурирующими именами PATH
- **GIVEN** проект без venv/override, пригодный preferred Python и другой нерабочий CLI
- **WHEN** пользователь открывает файл и запускает Current Python file через F5
- **THEN** используется штатный preferred Python данной ОС и реальный debugpy
- **AND** breakpoint/output/continue работают без установок и modal prompt

#### Scenario: Явно выбран непригодный SDK
- **WHEN** Current File запускается с explicit SDK, который не выполняет native probe
- **THEN** adapter/session не запускаются, UI остаётся доступным, path/stderr есть в Logs
- **AND** исправление пути позволяет повторить тот же запуск без restart и переустановки

#### Scenario: Смена проекта во время probe
- **WHEN** cwd меняется до завершения SDK probe
- **THEN** прежний запуск отменяется и программа в другом проекте не стартует
