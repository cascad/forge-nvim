# Design

## Context

См. proposal.md. state.is_main_window проверяет valid/non-float/buftype и собственный tool список; activities.find_code_window не запрещает float/terminal; panel_guard имеет private predicates, markers, Edgy и winfix fallback. У этих слоёв разные полномочия.

## Goals / Non-Goals

**Goals:** получить точные native контрпримеры эквивалентности, доказательства текущего restore и ограничения безопасного упрощения.

**Non-Goals:** изменение классификации/focus timers, экспорт private predicates, новый window manager, SDK/backend/Dependency изменения. Баги регистрируются отдельно; здесь нет product fix.

## Decisions

- Probe создаёт реальный private editor через существующий editor helper. Public finders вызываются на реальных buffers/windows; guard проверяется через public sweep, без debug.getupvalue, API wrappers и mocks.
- По одному profile на сценарий: normal, float-only, terminal-only, live marker, native session winfix. Session сохраняет реальные options через Persistence.save, load идёт через Persistence.load и штатные LoadPre/Post; файл копируется в artifacts.
- Probe сохраняет состояние до/после, выбранные window ids, создание split, current focus, buffers/options/markers, quit capture и точные source SHA. Наблюдаемые неудобства не превращаются в ожидаемое поведение regression suite: инструмент диагностический, не в общем registry.
- Windows и Ubuntu последовательно, готовый Docker image offline. macOS и физическая доставка клавиш — отдельно.

## Risks / Trade-offs

- Autocmd guards выполняются асинхронно → помечать synchronous снимки и settled снимки отдельно, не объявлять искусственно созданный state обычным пользовательским workflow.
- Session может скрыть source errors через silent! → сохранять session contents, сообщения/notifications и LoadPre/Post, проверять существование файлов/восстановленных buffers.
- Без нескольких сохранённых версий не доказана миграция всех старых sessions → это bounded fixture с native winfix, не общее доказательство restore.
