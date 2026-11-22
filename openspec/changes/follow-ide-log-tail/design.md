## Context

Один readonly Logs buffer общий для вкладок, native windows имеют отдельные
winsaveview. refresh строит bounded текст, затем всегда возвращает старый view.
Session sidecar восстанавливает view после native open.

## Goals / Non-Goals

Goals: последний текст сразу виден; обновления не мешают чтению истории;
обычный порядок сообщений и существующий session restore сохранены.
Non-Goals: reverse sort, новый renderer/скроллбар, изменение recorder/IO/лимитов,
языковые установки, общий рефакторинг панелей.

## Decisions

Снимать cursor/view до замены lines; если cursor был на последней строке —
переходить к новой последней строке с native normal! zb. Иначе winrestview.
Применять отдельно для каждого окна, без смены фокуса. Explicit source/filter
передаёт tail intent. open после создания окна перематывает только новое view;
повторный focus уже открытой панели сохраняет чтение. Session restore позже
применяет сохранённый sidecar, default open ему не препятствует.

## Risks / Trade-offs

Нужно проверить shrink после filters, скрытие/переоткрытие, native file source
и сессии разных вкладок/проектов. Автотесты используют настоящую панель и
public recorder, не подменяют refresh/provider. Mac физически не доступен.

## Open Questions

Нет.
