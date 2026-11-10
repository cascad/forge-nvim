# Design

## Context

Native baseline §166 подтверждает четыре разных backend, сохранённые files/cursors/tabs, но разный focus Space qs и config.start restore. После persistence.load общий PersistenceLoadPost открывает Explorer/focus_main, panel_guard выполняет sweep; config.start дополнительно schedule cleanup_restored_session и project:open. Последнее открытие выбирает дерево.

## Goals / Non-Goals

**Goals:** один согласованный restore/focus маршрут; native source RED→PASS, старый winfix recovery и fallback к listed file сохраняются; production сокращается без новых flags/controllers/timers.

**Non-Goals:** переписывать cwd/history/project detection, менять native restart или процессы, удалять рабочие UI, менять plugins/SDK; active DAP при restore, branch session/last/select/stop и write failure остаются самостоятельными сценариями.

## Decisions

- Усилить существующий native project-session E2E требованием IDE-PANEL-15: actual current window/filetype/buftype/floating/marker, не слова в Session.vim. Source c1beaaa перед runtime edits должен дать RED на project return; весь прежний layout/content/exit baseline сохраняется.
- Проверить реальные legacy sessions через native mksession: winfix и named listed file при help-only окне. Не считать private helper мёртвым только по одному healthy layout.
- Предпочтительный runtime шаг — удалить повторный scheduled cleanup/open из config.start и dead helper, потому что готовые LoadPost/panel_guard уже владеют этими фазами. Если native probe докажет необходимый fallback, сохранить только эту ответственность в существующем общем hook; не переносить destructive cleanup в manual restore с активными инструментами.
- Использовать существующие private TUI/profile/owned scope и наблюдаемый Job accounting drain. Никаких Docker/WSL операций. Ubuntu/Mac gates указываются по реальному результату.

## Risks / Trade-offs

Legacy-only сценарий может выявить роль старого helper — решать по source probe, а не добавлять компенсационный focus после второго открытия. Native event scheduling может быть асинхронным: готовность определяется actual windows/lifecycle, а не дополнительным timer. Windows PASS не заменяет native Ubuntu/Mac.

## Native решение после probes

Source c1beaaa: обычный возврат и legacy winfix возвращают дерево; валидная Help-only session с listed file приводит к NUI invalid-window/hit-enter после двух restore callbacks. Trial только без второго callback дал PASS обычному/winfix, но потерял file/Explorer fallback в Help-only. Поэтому полное удаление fallback отклонено.

Существующая функция config.start теперь выполняет только выбор main и listed-file fallback, возвращая window ID. Общий LoadPost вызывает её перед reveal, затем возвращает фокус в это окно. Так Help из SDK вне project cwd не вызывает reveal/root prompt. Второй cleanup/open из config.start удалён; destructive cleanup не переносится в manual restore. Winfix по-прежнему принадлежит panel_guard; SavePre cleanup прежний. Production net -8 строк, новых controllers/timers/flags нет.
