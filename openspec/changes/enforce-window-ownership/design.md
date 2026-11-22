## Context

Разбор docs/PANEL_OWNERSHIP_REVIEW.md: winfixbuf работает в core, но запрещает
также законную смену буфера Neo-tree. Backend предоставляет before/after open
events до nvim_win_set_buf. Existing registry уже объявляет filetypes и lifecycle.

## Goals / Non-Goals

Goals: один predicate/contract для editor/tool/transient; native buffer guard;
контролируемые backend transitions; Help/temporary не восстанавливаются;
документы, splits, modified buffers и jobs сохраняются.
Non-Goals: sandbox произвольного Lua, перехват глобальных nvim API, замена
Edgy/DAP/backend, переработка slow filesystem IO, новые языки/оформление.

## Decisions

Registry — источник role/lifetime/family/filetypes. Common ownership controller
применяет разрешения и window markers; state/buffers/guard используют его
классификацию. Вспомогательные transient types объявляются там же, не в нескольких
модулях. Native special buffers по умолчанию transient, обычные файлы — editor.
При смене источника backend заранее отпускает свой guard, после события вновь
проверяет owner; scheduled reconciliation завершает также ошибочный переход.
Не создавать бесконечные unlock timers. Ошибочная подмена repair-ится с возвратом
owned buffer, файл сохраняется в editor/списке; размер окна не определяет владельца.
Сессия использует существующий capture/restore views: UI закрывается после capture,
Help исключается native sessionoptions и legacy cleanup. Не удалять modified
документы и не завершать живые терминалы ради скрытия окна.

## Risks / Trade-offs

Backend может менять buffer вне registry entrypoint. Проверить pinned providers
реальными E2E; использовать их lifecycle events. Отсутствие подходящей границы —
повод предъявить ограничение, а не вводить глобальный monkeypatch.
Native bang может обойти winfixbuf; repair — дополнительная защита, не sandbox.

## Open Questions

Нет решений, требующих выбора владельца до начала работы. Физические keys/Mac
остаются отдельной приёмкой; Windows/Ubuntu native routes проверяются здесь.
