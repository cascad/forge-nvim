# Design

## Context

См. proposal и ответ владельца: важна именно цельная цветная рамка. Stock Neovim winborder — для floats; Edgy требует laststatus=3. Изображать четыре рамки посредством дополнительных окон/обёрток до review было бы новым lifecycle. Поэтому первый опыт использует уже существующий zoom Locals и сохраняет этот предел явно; постоянные рамки обычных split этим не реализуются.

## Goals / Non-Goals

**Goals:** реальное сравнение baseline/full border, active/dim, geometry и восстановление на paused DAP; переносимые доказательства и удобная команда повторения.

**Non-Goals:** применять стиль по умолчанию, заменять layout/менеджер окон, выдавать zoom за постоянные рамки каждого split, копировать Termide Rust или менять SDK/pins/shell. Выбор общей реализации и physical GUI остаются после прототипа.

## Decisions

- Test-only module оборачивает существующий controls.refresh только при явном start, украшает только native float Locals; источник данных/выбор/Space w/q/Esc/help принадлежат прежнему controls. Встроенная title занимает верхнюю линию border, duplicate winbar убирается. Stop восстанавливает функцию, window options и highlights; оформление product Lua не меняется. Отдельный IDE-PANEL-18 фиксирует native placement общего zoom.
- Для наглядного сравнения E2E ставит этот же zoom overlay над исходным slot: source32×12 с winbar даёт32×11 текста; compact inner31×11, outer33×13 занимает winbar/разделитель, теряется один столбец. В полном zoom136×40 снятие duplicate winbar возвращает строку (39→40). Это sample, не постоянная рамка split и не общий layout.
- В inactive состоянии реальный фокус получает существующая помощь: common zoom штатно сохраняется, граница Locals становится dim. Возврат в код штатно закрывает zoom. Не создавать собственный float/controller ради постоянного inactive окна.
- Тестовый RPC по явному флагу пишет bounded raw UI redraw JSONL и checkpoints в owned artifacts. Без флага capture отсутствует. Ошибка/limit capture записывается отдельно и не ломает RPC/выход процесса.
- Stdlib Python replay понимает RGB highlights/defaults, resize/line/repeat/clear/scroll/cursor, сохраняет SVG и HTML. Это реконструкция native UI grid, не physical WezTerm screenshot. Дополнительные графические packages для обязательных tests не нужны.
- Native UI capture E2E проверяет wide UTF8/RGB/scroll/resize и контролируемый limit при живом RPC. Отдельный editor/DAP E2E проверяет настоящий breakpoint, данные/output/frame, границы/цвета/геометрию и restore. Windows/Ubuntu поочерёдно, готовые deps/engine; Mac отдельно.
- MessagePack Window handles могут приходить бинарными строками: невалидный UTF8 сохраняется hex-объектом, валидный text неизменен. Replay использует только protocol grid events; malformed/unsupported grid не выдаются за картинку. SVG соединяет box glyphs vector strokes; font/DPI/cursor/underline остаются пределом экспорта.
- Go source readiness принимает только известный gopls WARN через existing ack_warning: этот DAP prototype не требует LSP. Другой blocking prompt остаётся ошибкой. Cleanup ошибки добавляются после первичной, не подменяют её exit assertion.

## Risks / Trade-offs

- Документация Termide main может отставать от source → закреплён tree d701d7b9 и фактический panel_rendering.rs.
- PNG/шрифт/DPI не равны WezTerm GUI → canonical SVG и raw JSONL, ограничения рядом со сравнением.
- Full border в zoom не решает обычный split → показать исходный split и записать цену/недостающий отдельный дизайн, не закрывать весь IDE-076.
- Отладчик/асинхронный redraw → ждать actual breakpoint/output и UI flush, не заменять backend ответами fixture.
- Raw UI может быть большим → явный byte cap, диагностический failure и штатный cleanup; не объявлять неполную запись PASS.
