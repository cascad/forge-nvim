## Purpose

Последовательность normal-команд управления окнами и файлами сохраняет
порядок ввода и последний явный выбор пользователя без позднего возврата.

## ADDED Requirements

### Requirement: IDE-PANEL-22 Порядок normal-команд управления

В normal mode редактор SHALL выполнять команды focus/window cycle/buffer
cycle/close context в порядке их ввода. Предыдущая команда SHALL NOT позднее
отменять следующий явный выбор панели или закрывать её вместо исходного
сохранённого файла. Существующий выход из insert/terminal в normal SHALL
сохранять текст, процессы и историю. Интерактивное подтверждение modified
file остаётся отдельным действием пользователя.

Платформы: все
Проверка: tests/e2e/focus-command-order.test.lua и existing buffers/terminal E2E.

#### Scenario: Normal focus и следующая панель
- **GIVEN** редактор находится в normal mode
- **WHEN** пользователь последовательно вводит F7 или F6, затем Space w i
- **THEN** Logs остаётся в фокусе после обработки ввода и callbacks

#### Scenario: Смена или закрытие файла перед Logs
- **GIVEN** открыты сохранённые файлы и normal mode
- **WHEN** пользователь переключает buffer или закрывает текущий context,
  затем выбирает Logs
- **THEN** файловая операция выполнена над исходным context, Logs не закрыт
  и остаётся выбранным

#### Scenario: Другие режимы
- **WHEN** F7 вызывается из insert или из настоящего terminal input
- **THEN** редактор выходит в normal и фокусирует code
- **AND** введённый текст либо terminal job/channel/history сохраняются
