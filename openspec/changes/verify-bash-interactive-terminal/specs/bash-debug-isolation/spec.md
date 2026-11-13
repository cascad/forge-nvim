## Purpose

Остановка Bash debug должна сохранять остальные задачи редактора, а
проверенное исправление SDK должно подготавливаться явно и воспроизводимо.

## ADDED Requirements

### Requirement: IDE-SH-6 Изоляция Bash debug Stop
Редактор SHALL останавливать только процессы выбранного Bash debug-сеанса.
Другие Editor jobs, terminals и language servers MUST сохраняться.
Запуск SHALL отклонять непроверенный SDK с понятной инструкцией подготовки;
обычный startup/launch MUST NOT изменять исходники adapter или устанавливать tools.
Платформы: все.
Проверка: tests/e2e/bash-interactive.test.lua и tests/e2e/bash-debug.test.lua.

#### Scenario: Stop во время read
- **GIVEN** Bash ждёт stdin и отдельный job редактора работает
- **WHEN** пользователь нажимает Shift-F5 в terminal-mode
- **THEN** Bash debug завершается до закрытия IDE
- **AND** независимый job остаётся работающим

#### Scenario: Нормальное завершение
- **GIVEN** Bash запрашивает строку через native PTY
- **WHEN** пользователь вводит строку и программа заканчивается
- **THEN** stdin/stdout и scrollback сохраняются, другие Editor jobs работают
- **AND** backend завершается до закрытия IDE

#### Scenario: Явная подготовка SDK
- **GIVEN** известный непоправленный adapter установлен
- **WHEN** пользователь нажимает F5
- **THEN** adapter не запускается и показывается инструкция BashDebugPrepare
- **AND** только явная подготовка изменяет проверенные bytes; unknown SDK сохраняется
