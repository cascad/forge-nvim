## Purpose

Отладка Bash текущего файла и явной launch.json цели в общем keyboard
workflow IDE с готовым DAP backend на Windows, Linux и macOS.

## ADDED Requirements

### Requirement: IDE-SH-5 Bash debug с готовым backend
Редактор SHALL запускать текущий Bash файл через F5 без launch.json и
поддерживать явный type=bashdb launch.json. Breakpoint, переменные/стек,
вывод, continue, stop и повтор SHALL использовать общие DAP панели/клавиши.
Windows MUST использовать выбранный владельцем WSL2 backend; Linux/macOS —
native Bash4+. Запуск IDE MUST NOT устанавливать tools или запускать WSL.
Отсутствующий adapter/Node SHALL давать понятное сообщение при попытке debug.
Платформы: все; native Mac требует отдельной проверки.
Проверка: tests/e2e/bash-debug.test.lua.

#### Scenario: Текущий файл
- **GIVEN** сохранён Bash файл и подготовлен adapter/backend
- **WHEN** пользователь ставит breakpoint и нажимает F5
- **THEN** открываются общие Debug панели, доступны переменные и стек
- **AND** continue показывает stdout, после изменения файл можно запустить снова

#### Scenario: Явный debug case
- **GIVEN** launch.json с type=bashdb и собственными args/env/cwd
- **WHEN** пользователь выбирает этот case
- **THEN** выполняется выбранная цель с её настройками и доступен штатный stop

#### Scenario: Недоступный adapter
- **GIVEN** adapter или Node отсутствует
- **WHEN** пользователь пытается начать Bash debug
- **THEN** IDE сообщает недостающий инструмент без установки или скрытого fallback
