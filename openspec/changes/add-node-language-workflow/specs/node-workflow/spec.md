## Purpose

Редактор поддерживает повседневный JS/Node workflow в существующих языковых,
тестовых и отладочных панелях с одинаковыми командами на целевых системах.

## ADDED Requirements

### Requirement: IDE-NODE-1 JavaScript LSP и форматирование
Редактор SHALL предоставлять JS definition/references/rename/completion и
diagnostics через доступный языковой сервер и форматировать код доступным
Prettier либо LSP. Project-local tools SHALL иметь приоритет над общими.
Открытие файла MUST NOT устанавливать инструменты или зависать при их отсутствии.
Платформы: все
Проверка: tests/e2e/node-language.test.lua (реальный server, local dependencies, format)

#### Scenario: Работа с несколькими файлами
- **WHEN** пользователь открывает JS модуль, переходит к символу, переименовывает его и принимает LSP completion
- **THEN** семантика работает в реальном проекте, диагностика обновляется, изменения сохраняются

#### Scenario: Формат проекта
- **WHEN** пользователь форматирует JS с project-local Prettier/config
- **THEN** используется локальный инструмент и результат сохраняется в стиле проекта

### Requirement: IDE-NODE-2 Node run и package scripts
Редактор SHALL запускать текущий исполняемый JS файл и выбранный package script
в существующем Tasks, с project cwd и корректными argv для Unicode/пробелов.
Output/status SHALL быть доступны обычными командами панелей без мыши.
Платформы: все
Проверка: tests/e2e/node-language.test.lua (настоящие Node/npm processes)

#### Scenario: Запуск файла и script
- **WHEN** пользователь вызывает NodeRunFile либо выбирает script через NodeRun
- **THEN** выполняется реальный процесс в проекте, stdout/stderr и итог видны в Tasks

### Requirement: IDE-NODE-3 Node DAP и запуск без конфига
Редактор SHALL предоставлять F5 текущего JS без launch.json и поддерживать
явный проектный Node launch.json, breakpoint/eval/continue и stdout/stderr.
При отсутствии Node/debug adapter SHALL появляться понятное сообщение без
установки инструмента и зависшей сессии. Открытие чужого файла MUST NOT выдавать
предупреждения о Node toolchain.
Платформы: все
Проверка: tests/e2e/node-language.test.lua (реальный js-debug/Node, negative)

#### Scenario: Default и project debug
- **WHEN** пользователь запускает F5 без launch.json либо выбирает проектный Node config
- **THEN** процесс останавливается на breakpoint, значение доступно для eval, после continue виден вывод

#### Scenario: Adapter отсутствует
- **WHEN** пользователь явно запускает Node debug без нужного инструмента
- **THEN** редактор объясняет проблему, не устанавливает tools и остаётся пригоден для работы

### Requirement: IDE-NODE-4 Jest в общей Tests панели
Редактор SHALL выполнять nearest/file Jest тесты и показывать реальные результаты/
вывод в общей Tests/Test Output. Debug nearest SHALL использовать Node DAP.
Nearest MUST NOT запускать соседний тест. Project-local Jest и пути с пробелами
SHALL поддерживаться без разбиения argv по пробелам.
Платформы: все
Проверка: tests/e2e/node-language.test.lua (реальный Jest/Neotest/Node debug)

#### Scenario: Nearest и файл
- **WHEN** пользователь запускает Tt или Tf в Jest проекте
- **THEN** nearest запускает выбранный тест, file показывает pass/fail, текст результата сохраняется

#### Scenario: Debug теста
- **WHEN** пользователь ставит breakpoint и запускает Td
- **THEN** настоящий тест останавливается, eval и continue работают, итог виден в выводе
