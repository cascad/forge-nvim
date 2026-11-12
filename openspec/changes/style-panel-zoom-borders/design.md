# Design

## Context

См. proposal; общий zoom уже создаёт native floating window. Стиль prototype
проверен в panel-frame, но пользовательский путь пока использует старый winbar.

## Goals / Non-Goals

Оформить существующий zoom без нового layout owner, плагина и polling.
Постоянные рамки split/распространение frame pilot и физическая оценка вне шага.

## Decisions

- Локальный refresh_zoom в ide.controls задаёт native title/FloatBorder/winbar
  одному действующему overlay при создании и существующем refresh.
- Использовать DiagnosticInfo/Comment текущей темы; title содержит [focus]
  только при фокусе. Исходный split и его options не менять.
- Дополнить существующий debug-panels capture_ui и одним permanent RGB E2E
  настоящих Locals/Output/Files/Logs; готовый render-ui экспортирует SVG/JSON.
- Один Windows selected прогон: debug-panels/work-panels/outline/git-workflow/
  tool-panels/frame-layout. При FAIL сохранить результат и остановить итерацию.

## Risks / Trade-offs

Edgy/справка могут изменить overlay: прежний window-local opt-out и native E2E.
Регресс обычного winbar: проверять исходный options до/после. Цвет проверять
по фактическим RGB cells, не только Lua options. Mac/font/physical GUI отдельно.
