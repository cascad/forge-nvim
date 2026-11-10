# Design

## Context

Space du вызывает ide.dap.toggle. Он проверяет activities.debug_filetypes, затем activities.close_debug. Оба пути знают REPL/Console/sidebar, но пропускают существующий dap-terminal. Native profile 34018783081000 воспроизводит оставшийся PTY при закрытом sidebar, с сохранённой паузой.

## Goals / Non-Goals

Цель — завершить существующий контракт Debug group для PTY двумя дополнениями общих таблицы и close route. Не объединяем прочие панели, не переписываем FSM, не меняем SDK, не объявляем это причиной IDE-090/Docker.

## Decisions

- Добавить dap-terminal в существующую debug_filetypes и ide.hide('dap.terminal') в общий close. Fallback закрывает окно по той же таблице. Backend component.close уже сохраняет buffer/PTY.
- Два native E2E на реальном paused CodeLLDB: видны sidebar+PTY; виден только PTY. Toggle закрывает всю группу, следующий открывает прежний output; F5 продолжает тот же PTY и даёт итоговый stdout.
- Сохранять native exit/API errors/scope evidence и source snapshots. Старый source replay должен давать RED до runtime fix; положительный suite без mock DAP.

## Open Questions

Причина единичного IDE-090 sidebar failure; не блокирует независимо воспроизведённый IDE-091. Ubuntu engine и Mac недоступны агенту.
