## ADDED Requirements

### Requirement: IDE-PANEL-14 Явное hide переживает startup recovery

Редактор SHALL сохранять Debug панели скрытыми после явного q/toggle пользователя во время running сессии до ручного открытия или нового actual stopped event; отложенный startup recovery не отменяет hide. Первоначальные sidebar/Output и новый breakpoint SHALL по-прежнему открываться, существующий PTY и его вывод сохраняются.
Платформы: все
Проверка: tests/e2e/debug-startup-visibility.test.lua, dap-output-policy/debug-panels и language debug E2E

#### Scenario: Hide вскоре после initialized
- **GIVEN** CodeLLDB ещё выполняет программу, виден настоящий PTY, breakpoint позже
- **WHEN** пользователь скрывает Output через q и группу через Space du до истечения startup recovery
- **THEN** группа остаётся скрытой после прежнего800ms deadline, сессия продолжает работу
- **AND** новое stopped event открывает sidebar и тот же PTY, F5 дописывает итоговый stdout
