## Purpose

Python debug использует доступную managed среду адаптера независимо от
проектного Python, сохраняя native layout целевых ОС и явные overrides.

## ADDED Requirements

### Requirement: IDE-PY-2 Native managed Python debug adapter

При готовом managed debugpy venv редактор SHALL находить native launcher
адаптера либо Python этой managed среды на Windows/macOS/Linux. Project
interpreter SHALL сохраняться для debuggee, даже когда debugpy отсутствует
в project venv. Явные adapter/Python overrides и их приоритет global перед
env SHALL сохраняться. Открытие Python файла MUST NOT устанавливать tools
или запускать debug adapter; F5 SHALL сохранять breakpoint/eval/output/continue.
Платформы: все
Проверка: tests/e2e/python-managed-debug.test.lua

#### Scenario: Managed launcher
- **GIVEN** debugpy установлен только в готовом managed venv, project venv содержит зависимости приложения
- **WHEN** пользователь запускает текущий Python файл через F5
- **THEN** настоящий managed launcher открывает debug session, приложение выполняется project Python
- **AND** breakpoint/eval42/stdout/continue доступны без установки tools

#### Scenario: Managed Python fallback
- **GIVEN** launcher отсутствует, managed Python может импортировать debugpy, project Python не может
- **WHEN** пользователь запускает текущий файл через F5
- **THEN** adapter запускается через managed Python, а приложение через project Python

#### Scenario: Explicit adapter
- **GIVEN** готовы разные managed и explicit adapter, global override отличается от env override
- **WHEN** пользователь запускает F5
- **THEN** используется явно выбранный global adapter, project interpreter сохраняется

#### Scenario: Explicit adapter Python
- **GIVEN** launcher отсутствует, global Python override отличается от env override
- **WHEN** пользователь запускает F5
- **THEN** adapter использует явно выбранный global Python, project interpreter сохраняется
