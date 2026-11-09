## Purpose

Ожидаемое завершение adapter не мешает результату отладки; настоящий отказ
adapter остаётся заметным пользователю.

## ADDED Requirements

### Requirement: IDE-DAP-5 Ожидаемый и неожиданный adapter exit
Редактор SHALL различать завершение stdio adapter после запроса client close
и его неожиданный nonzero exit до такого запроса. Первое MUST NOT создавать
ложный error/WARN поверх успешного test result; второе SHALL сохранять
понятный WARN/stderr и возможность продолжить работу. Raw exit codes MUST
сохраняться в log, исходники plugin MUST NOT изменяться обычным startup.
Платформы: все
Проверка: tests/e2e/python-language.test.lua (pytest debug и unexpected adapter exit)

#### Scenario: Успешный pytest debug
- **WHEN** после настоящего breakpoint/eval/continue pytest завершается с кодом 0 и frontend закрывает stdio adapter
- **THEN** итог теста и output доступны без ложного adapter exit WARN
- **AND** raw log продолжает показывать фактический adapter exit code

#### Scenario: Неожиданный отказ adapter
- **WHEN** пользователь запускает реальный ошибочный adapter process, который умирает до client close
- **THEN** WARN остаётся видимым, сессия завершается и файл можно редактировать
