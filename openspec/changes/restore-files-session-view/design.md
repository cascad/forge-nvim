# Design

## Context

См. PROJECT_SESSION_REVIEW и proposal. Native mksession сохраняет code windows,
а cleanup намеренно удаляет tool views. Оба существующих save routes должны
снять view до cleanup. Neo-tree renderer и Edgy resize уже используются в сборке.

## Goals / Non-Goals

Первый срез WF-01/02 — только Files во всех code tabpages. Не менять layout
owner, не сериализовать процессы/копии tool buffers и не менять plugin pins.
Остальные панели и их геометрия остаются отдельной незавершённой частью WF-01.

## Decisions

- session_files снимает native дерево до cleanup, после успешного mksession
  пишет JSON в stdpath(state)/forge-session-views. Ключ — canonical session
  path, внутри SHA session file: last/branch fallback и legacy sources различимы.
- Метаданные содержат только view/path/expanded IDs/ширину и tab order.
  SavePost фильтрует закрытые при cleanup tabpages по исходным handles.
- Explicit project save вызывает штатные SavePre/save/SavePost и останавливает
  autosave до restart; при failed restart возобновляет его, если он был активен.
- LoadPost сохраняет прежний focus route. Подходящий snapshot открывает Files
  через registry/Neo-tree последовательно по вкладкам; completion возвращает
  code focus и разрешает follow после последнего view. Без снимка остаётся
  прежний project:open; ошибка callback завершает restore с WARN.
- Neo-tree after_render применяет выбранный узел/view один раз; Edgy get_win/
  resize меняет размер текущей вкладки, затем callback допускает следующую.
  После winrestview штатный renderer.position.save обновляет сохранённую
  позицию для будущих redraw. Новых timers/polling/layout manager нет.
- Native filesystem.follow вызывается из документированного buffer-enter
  handler только при смене файла. Builtin повторный follow отключён, при
  SessionLoad он временно не вызывается. Рендер/сканирование остаются native;
  это сохраняет просмотр дерева при возврате фокуса в тот же файл.
- При малом UI ширина уменьшается пропорционально; отсутствующий node/path
  даёт существующий root. Исходные defaults после render возвращаются.

## Risks / Trade-offs

Порядок async render/Edgy и двойной save → native PTY quit/relaunch/A→B→A.
Данные старого session file → fingerprint + legacy controls. Обычный Files
lifecycle → file-explorer/outline-focus regression. Каждый набор один раз;
Windows в этой итерации, Ubuntu/macOS/physical GUI явно непроверены.
