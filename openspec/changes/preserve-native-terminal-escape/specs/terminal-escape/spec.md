# Spec Delta

## Purpose

Стандартный выход из терминального ввода должен оставаться предсказуемым после завершения команды и при повторном нажатии, сохраняя процессы, вывод и паузу отладки.

## ADDED Requirements

### Requirement: IDE-PANEL-16 Native escape в terminal buffer

Редактор SHALL сохранять native `Ctrl-\ Ctrl-n` для любого terminal buffer в terminal-input и terminal-normal. Chord и его повтор SHALL NOT открывать или скрывать другой терминал, заменять текущий buffer/channel, завершать процесс либо менять paused DAP session/frame. В terminal-normal одиночный `Ctrl-\` SHALL оставаться native prefix. Вне terminal buffers прежний normal `Ctrl-\` toggle SHALL сохраняться; normal `Ctrl-t` и `Space tt` SHALL по-прежнему открывать/скрывать managed terminal с прежним job и выводом. Печатный terminal input SHALL сохраняться.

Платформы: все.
Проверка: tests/e2e/terminal-escape.test.lua; Mac/GUI отдельно.

#### Scenario: Команда уже завершена
- **GIVEN** native terminal с выводом завершившейся команды уже находится в terminal-normal
- **WHEN** пользователь нажимает Ctrl-\ Ctrl-n, затем повторяет chord
- **THEN** остаётся тот же terminal buffer и вывод, новый managed terminal/job не появляется

#### Scenario: Живой terminal до и после загрузки plugin
- **GIVEN** настоящий interactive process принимает строки, terminal plugin ещё не загружен либо уже загружен
- **WHEN** пользователь вводит текст, выходит chord и повторяет его в terminal-normal
- **THEN** ввод/вывод, buffer/channel и живой PID сохраняются, extra terminal не появляется
- **AND** Esc Esc и F7 продолжают работать прежними путями

#### Scenario: Managed terminal и aliases
- **GIVEN** managed shell запущен и имеет вывод
- **WHEN** native escape повторяется, затем пользователь применяет normal Ctrl-t, Ctrl-\ из кода и Space tt
- **THEN** escape сохраняет окно/процесс, а явные toggle aliases скрывают/возвращают тот же managed terminal и вывод

#### Scenario: Настоящий DAP PTY на breakpoint
- **GIVEN** отладчик остановлен, реальный PTY уже содержит stdout
- **WHEN** пользователь выходит из terminal input и повторяет chord в terminal-normal
- **THEN** сохраняются PTY/buffer/channel и та же session/thread/frame без extra terminal
- **AND** последующий явный Continue дописывает stdout в прежний PTY
