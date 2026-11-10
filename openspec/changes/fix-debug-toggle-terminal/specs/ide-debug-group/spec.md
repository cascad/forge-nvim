## ADDED Requirements

### Requirement: IDE-PANEL-13 Полная группа Debug включает PTY

Редактор SHALL считать dap-terminal частью Debug при общем Space du toggle: если видна любая Debug панель, скрываются все окна Debug, включая PTY; повторное открытие возвращает последний Output без нового запуска программы. Buffer, PTY channel, сессия и пауза MUST сохраняться.
Платформы: все
Проверка: tests/e2e/debug-toggle.test.lua, tests/e2e/dap-output-policy.test.lua

#### Scenario: Sidebar и PTY
- **GIVEN** настоящий CodeLLDB остановлен на breakpoint, видны sidebar и PTY с stdout
- **WHEN** пользователь нажимает Space du
- **THEN** sidebar и PTY скрываются, фокус возвращается в код
- **AND** повторный Space du возвращает прежний PTY, а продолжение F5 добавляет stdout в тот же channel

#### Scenario: Только PTY
- **GIVEN** sidebar скрыт через q, PTY остаётся виден
- **WHEN** пользователь нажимает Space du
- **THEN** PTY скрывается, sidebar не открывается вместо скрытия
- **AND** ручное открытие восстанавливает тот же Output и ту же паузу
