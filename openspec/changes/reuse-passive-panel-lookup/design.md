# Design

## Context

См. proposal и свежий FEATURE_REVIEW §184. Activities.find_window уже умеет
искать по predicate без заданного FT, в native порядке текущего tab.

## Goals / Non-Goals

Удалить два дублирующих обхода без нового слоя. Не менять main finder,
создание/перенос code windows, predicates existing activities, layout owner,
SDK или optional UI. Ускорение из меньшего LOC не выводится.

## Decisions

- Init visibility делегирует activities.is_visible(nil, combined predicate).
  FT проверяется до source predicate через and; прямой is_visible(ft,predicate)
  отвергнут, поскольку существующий finder вызывает predicate и при другом FT.
- Registry default focus делегирует activities.focus_window(nil, FT predicate).
  Внешний цикл по FT отвергнут: он меняет window-first порядок на FT-first.
  spec.filetypes читается при каждом вызове, custom focus остаётся нетронутым,
  прежний nil return default callback сохраняется.
- Требуются только lazy require существующего module внутри callbacks.
  Activities не получает новый API или изменённые правила predicate.
- Native E2E: source baseline PASS → refactor PASS; это не исправление бага
  с выдуманным RED. Проверяется registry API с настоящими окнами и backend
  Neo-tree sources, плюс прежние пользовательские panel/debug/file E2E.

## Risks / Trade-offs

- Ранний require/cycle → require только при lookup/focus, не register/setup.
- Изменение приоритета/границы tab → first matching window среди нескольких FT,
  float/normal, no-match и matching только в другой tab в native E2E.
- Подмена source фильтра → реальные filesystem/buffers/git_status и закрытие.
- Dynamic metadata → live filetypes mutation и custom callback regression.
- Mac/physical keys → отдельно непроверено; код без platform веток.

## Migration Plan

Никакой миграции данных или смены настроек. Вернуть два коротких цикла —
полный откат. Закоммитить после Windows/Ubuntu E2E и истории.
