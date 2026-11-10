# Spec Delta

## Purpose

Возврат из рабочих панелей в обычное окно кода должен исключать terminal и floating preview и сохранять границу между поиском и созданием окна.

## ADDED Requirements

### Requirement: IDE-PANEL-12 Focus-only поиск обычного окна кода

Редактор SHALL выбирать для возврата фокуса обычное не-floating окно с обычным файловым буфером, сохраняя прежние исключения tool filetypes. Terminal и floating preview SHALL NOT считаться окном кода. Поиск и попытка focus без кандидата SHALL сохранять layout и возвращать отсутствие результата; явный переход в код может создать main через существующий state.

Платформы: все.
Проверка: tests/e2e/code-focus.test.lua, DAP/Output/language E2E.

#### Scenario: Terminal первым при существующем коде
- **GIVEN** настоящий PTY стоит перед обычным main окном
- **WHEN** пользователь открывает Debug View
- **THEN** фокус возвращается в обычное окно кода, а не в terminal
- **AND** PTY и его процесс сохраняются, Output доступен по прежним клавишам

#### Scenario: Только terminal
- **GIVEN** обычного окна кода нет
- **WHEN** вызывается focus-only поиск или попытка focus
- **THEN** terminal не выбирается и новые окна не создаются
- **AND** Space w 0 создаёт обычный main существующим механизмом

#### Scenario: Floating файл без main
- **GIVEN** обычное окно содержит tool buffer, файл виден только в float
- **WHEN** выполняется focus-only поиск
- **THEN** float не выбирается и layout сохраняется
- **AND** Space w 0 создаёт отдельный normal main и сохраняет preview
