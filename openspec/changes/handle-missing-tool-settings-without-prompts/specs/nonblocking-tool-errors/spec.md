# Spec Delta

## Purpose

Сохранить редактирование и понятную диагностику fride при отсутствии SDK/tools
или ошибочных явных путях, не меняя выбранную пользователем среду молча.

## ADDED Requirements

### Requirement: IDE-BOOT-41 Ошибки tools без блокировки редактора

Редактор SHALL обрабатывать отсутствие Node/Bash и их IDE tools/adapters либо
ошибку явного пути/JSON без hit-enter prompt из callbacks открытия файла,
Run/Debug и проверки доступности автоформатирования. Платформы: все.
Проверка: tests/e2e/missing-tool-errors.test.lua и прежние Node/Bash/Logs cases;
native macOS отдельно владельцем.

#### Scenario: Invalid selection while editing
- **GIVEN** explicit path отсутствует либо tools.json повреждён
- **WHEN** открывается JS/Bash файл и выполняется редактирование/сохранение
- **THEN** редактор остаётся доступным без подтверждения ошибки
- **AND** недоступный LSP не запускается и источник/причина доступны в Logs
- **AND** рабочая копия из PATH не заменяет явный выбор

#### Scenario: Failed run or debug
- **WHEN** Run/Debug требует отсутствующий SDK или adapter
- **THEN** выводится понятное сообщение, а причина неверного explicit choice сохраняется
- **AND** новая задача/сессия не создаётся, SDK/tools не устанавливаются

#### Scenario: Recovery and strict inspection
- **WHEN** пользователь исправляет настройку и повторяет действие
- **THEN** используется исправленный путь без обязательного перезапуска редактора
- **AND** strict resolver/report/setup продолжает отклонять неверные настройки
- **AND** повтор одного LSP события не засоряет Logs одинаковыми уведомлениями
