# Design

## Context

См. proposal. Восемь функций `ide.controls` начинают с одинаковых трёх
операций. Существующие E2E уже проверяют пользовательские переходы.

## Goals / Non-Goals

Общая локальная `prepare_navigation(enter)` сохраняет последовательность:
`pending_panel=nil`, `close_help(enter)`, `M.restore(enter)`.
Не менять show_work, zoom/cancel/help: у них иной порядок или условный restore.
Не менять backend, hotkeys, frame pilot и системные границы.

## Decisions

Заменить только восемь точных повторов. Одной локальной функции достаточно;
state/Edgy/DAP продолжают владеть прежними действиями. Перед тестами сверить
diff: исходные три операции в каждом entry должны совпадать с вызовом helper.
Использовать прежние E2E без нового тестового framework или зеркального unit.

## Risks / Trade-offs

Разный enter влияет на возврат cursor; true сохраняется у direction/hide,
false — у остальных шести. Проверить native help/zoom/focus/hide и frame pilot.
Windows — один selected прогон; Ubuntu/macOS отдельно непроверены этой итерацией.
