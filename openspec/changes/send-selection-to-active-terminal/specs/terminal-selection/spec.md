# Spec Delta

## Purpose

Выполнение выбранного текста в действующей встроенной консоли без мыши.

## ADDED Requirements

### Requirement: IDE-PANEL-30 Выделение выполняется в активной встроенной консоли

Редактор SHALL выполнять Visual selection через Space t e и Visual/Select selection через Ctrl+Enter
в последней активной обычной консоли ToggleTerm. Скрытая консоль SHALL открываться
с тем же job/cwd/history; при отсутствии консолей SHALL создаваться штатная
консоль проекта с прежней platform shell policy.
Консоль SHALL быть обычным системным shell в панели IDE с привычным environment
и tools; автоматический выбор REPL/interpreter по filetype не выполняется.
Char/line/block selection, Unicode, whitespace, exclusive selection и многострочный текст SHALL сохраняться
без trim/quoting, изменения source buffer/файла или yank registers. Повтор SHALL
переиспользовать сессию. Private hidden terminals MUST NOT становиться целью.
Законченный job SHALL показывать вывод и предупреждение без молчаливой замены
сессии. Native terminal focus rules и прежние transport aliases сохраняются.

Платформы: все; native Windows/Ubuntu, physical Mac/Omarchy отдельно.
Проверка: tests/e2e/terminal-selection.test.lua, tests/e2e/terminal-shell.test.lua.

#### Scenario: Первое выполнение
- **GIVEN** консоль ещё не создана
- **WHEN** пользователь выполняет выделение
- **THEN** открывается native integrated Terminal и вывод команды виден
- **AND** shell/cwd соответствуют обычной политике Terminal, файл/registers прежние

#### Scenario: Видимая либо скрытая консоль
- **GIVEN** существует active terminal job/shell/REPL
- **WHEN** выполняется новое выделение, в том числе повторно после hide
- **THEN** текст получает тот же job с сохранением buffer/channel/PID/cwd/history
- **AND** панель раскрывается, новая сессия не создаётся

#### Scenario: Несколько сессий
- **GIVEN** есть несколько обычных консолей и private hidden task terminal
- **WHEN** пользователь возвращается в код и выполняет выделение
- **THEN** выбирается последняя активная обычная консоль, остальные не получают текст

#### Scenario: Точный текст и переносимые клавиши
- **WHEN** отправляется char/line/block, reversed/exclusive или Unicode selection
- **THEN** native stdin получает выбранный текст с исходными пробелами/переносами
- **AND** Space t e работает без modified-key протокола; Ctrl+Enter/RU aliases используют тот же маршрут

#### Scenario: Консоль завершилась
- **GIVEN** active terminal завершён и хранит вывод
- **WHEN** пользователь пытается выполнить выделение
- **THEN** видит старую консоль и понятное предупреждение, job/history не заменены
