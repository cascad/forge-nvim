## Purpose

Холодный запуск готового Python debugger в смешанном проекте не останавливается
ложным предупреждением раньше завершения штатного handshake.

## ADDED Requirements

### Requirement: IDE-DAP-8 Ожидание холодного Python debugger
Python adapter SHALL ожидать initialize/launch в пределах30 секунд перед
предупреждением об отсутствии ответа. Реальный breakpoint, interpreter project
venv и Output MUST сохраняться; обычная ошибка запуска/exit SHALL оставаться
видимой без ожидания полного бюджета, если backend уже сообщил результат.
Платформы: все.
Проверка: tests/e2e/mixed-project.test.lua, tests/e2e/python-language.test.lua.

#### Scenario: Готовый debugpy после открытия нескольких языков
- **GIVEN** несколько готовых LSP и cold debugpy, отвечающий позднее4 секунд
- **WHEN** пользователь запускает Current Python file из локального venv
- **THEN** достигается breakpoint с правильным interpreter и доступным Output
- **AND** ложное предупреждение4s не блокирует UI, continue завершает программу

#### Scenario: Настоящая ошибка adapter
- **GIVEN** Python adapter завершился с ошибкой
- **WHEN** пользователь запускает debug
- **THEN** его настоящая причина отображается без ожидания всех30 секунд
