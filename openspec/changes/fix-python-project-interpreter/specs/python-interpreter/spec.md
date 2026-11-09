## Purpose

Python LSP использует доступные зависимости того же проектного окружения,
которое выбирается для обычного запуска и отладки Python.

## ADDED Requirements

### Requirement: IDE-PY-1 Python interpreter проекта
Редактор SHALL передавать Pyright интерпретатор доступного проектного venv,
согласованный с существующим выбором Python DAP. Неактивированный .venv MUST
работать без extraPaths и дополнительного venv config в тестовом проекте.
Явный python.pythonPath MUST сохраняться. Выбор MUST NOT устанавливать tools,
запускать DAP или требовать shell activation при открытии Python файла.
Платформы: все
Проверка: tests/e2e/python-language.test.lua (LSP dependency definition и реальный DAP/pytest interpreter)

#### Scenario: Project venv без активации
- **GIVEN** dependency установлена только в project .venv, shell не активировал эту среду
- **WHEN** пользователь открывает импортирующий Python файл и выполняет gd
- **THEN** Pyright находит определение в project .venv без import error
- **AND** обычный F5 использует ту же project среду и показывает настоящий stdout/stderr

#### Scenario: Сохранение остальных сценариев
- **WHEN** пользователь запускает pytest nearest/file либо debug nearest после изменения selector
- **THEN** реальные tests используют project venv, breakpoint/eval/continue и результат работают
