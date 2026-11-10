# Design

## Context

Реальный running CodeLLDB: hide89.6ms после initialized, startup watchdog через716.4ms после hide открыл sidebar без нового stopped event. В историческом первом IDE-090 trace отсутствовал; доказана воспроизводимая гонка того же наблюдаемого класса.

## Goals / Non-Goals

Уважать явное hide и сохранить auto-open новой сессии/остановки/PTY. Не вводить tokens/generations/UI controller и не связывать это с Docker. Отдельный IDE-093 padding test bug не подменяет IDE-090.

## Decisions

- Удалить800ms callback и использовавшийся только им bottom_debug_visible. Уже существующие initialized и runInTerminal открывают первоначальный вид, stopped восстанавливает панели при новой остановке.
- Native E2E после удаления timer обнаружил прежний guard stopped_thread_id: pinned nvim-dap заполняет его после async threads response, поэтому scheduled callback успевал отказаться. На actual stopped event достаточно сохранить guard той же активной сессии; новые timers/state не нужны. Это необходимо для сохранения заявленного auto-open после новой остановки.
- Один настоящий Rust scenario без timer mocks:4s sleep до breakpoint, первый живой PTY скрывается q/du до700ms от actual initialized. После1200ms Debug всё ещё скрыт; stopped возвращает sidebar/тот же канал, Continue добавляет stdout.
- При слишком медленном host явно отказывает fixture precondition вместо ложного PASS. Native timestamps получены public DAP event listener; тот не подменяет handlers. Положительные language/output/panel tests защищают auto-open.

## Open Questions

Единственность причины исторического32921392974800 недоказуема без его trace. Mac/Ubuntu требуют native runs.
