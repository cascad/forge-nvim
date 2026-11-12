## Purpose

Диагностика неуспешного старта настоящего debugpy видна в редакторе
и общей консоли, сохраняя подробности native stderr и работоспособность IDE.

## ADDED Requirements

### Requirement: IDE-DAP-6 Неуспешный старт debugpy виден пользователю

Редактор SHALL показывать предупреждение о неожиданном ненулевом выходе
stdio debugpy и сохранять его в общей консоли IDE. Видимость SHALL NOT зависеть
от имени Python executable. Native stderr SHALL сохранять подробную причину.
Ожидаемый shutdown после client close SHALL оставаться без ложного exit WARN;
после отказа пользователь SHALL иметь возможность продолжить редактирование.

Платформы: все
Проверка: tests/e2e/debugpy-exit.test.lua; python-language pytest debug.

#### Scenario: Ошибка аргументов настоящего адаптера
- **WHEN** реальный установленный debugpy.adapter завершается до initialize
  из-за неверного CLI аргумента с ненулевым кодом
- **THEN** предупреждение с типом adapter и кодом видно в UI и IDE Logs
- **AND** native stderr содержит ошибочный аргумент, session завершена,
  source file можно изменить и сохранить

#### Scenario: Штатное завершение отладки
- **WHEN** настоящий pytest debug завершается успешно и клиент закрывает stdio
- **THEN** результат и Output доступны без ложного adapter exit WARN
- **AND** raw exit остаётся в native log
