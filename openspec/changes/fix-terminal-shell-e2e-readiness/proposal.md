# Proposal

## Why

IDE-113: общий Windows E2E source dab7bf6 читает terminal-shell.again сразу
после создания и получает пустой файл (profile13792255328900). Это ошибка
наблюдения IDE-PANEL-19: filereadable не означает завершение shell command.
Отдельный shutdown SIGTERM profile13758269241400 остаётся IDE-085.

## What Changes

- Ожидать полного содержимого результата реальной shell command.
- Защитить ожидание постоянной fixture с созданием пустого файла до записи;
  сохранить настоящее выполнение shell/PTY, PID/channel/history и source RED.
- Сохранить первичный общий FAIL и отдельную диагностику IDE-085;
  выбранный PASS не превращает старый общий прогон в PASS.

## Capabilities

### New Capabilities

Нет. skip_specs=true: исправляется тестовый observer, поведение IDE не меняется.

### Modified Capabilities

Нет. IDE-PANEL-19 сохраняется, новая продуктовая delta не требуется.

## Impact

tests/e2e/terminal-shell.test.lua и постоянная fixture, история и результаты
Windows/Ubuntu. Product Lua, shell policy, SDK/pins и quit timeout прежние.
Native Mac/physical keys остаются отдельным gate.
