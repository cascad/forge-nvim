# Proposal

## Why

IDE-095: native A→B→A возвращает фокус в Explorer при сохранённых files/tabpages/cursors, хотя общий PersistenceLoadPost обещает возврат в editor. Config.start после persistence.load запускает второй scheduled cleanup/project:open; общий hook и panel_guard уже обрабатывают restore.

## What Changes

- Закрепить IDE-PANEL-15: успешная загрузка сессии с файлами открывает Explorer и оставляет фокус в обычном окне кода, одинаково для Space qs и project restart.
- Получить permanent native source RED на текущем config и убрать подтверждённый повторный маршрут, сохранив layout/содержимое и старую winfix recovery.
- Проверить существующий fallback к listed file, когда сохранённое окно не является кодом, прежде чем удалять helper; сохранять необходимую ответственность без нового lifecycle controller.
- E2E/история/инструкции и явные Windows/Ubuntu/Mac gates.

## Capabilities

### New Capabilities

- `project-session-focus`: IDE-PANEL-15, клавиатурный фокус после session restore.

### Modified Capabilities

Нет основной IDE спеки: phase1 main specs пока содержат WezTerm; новый delta не переписывает baseline.

## Impact

Config.start и существующий PersistenceLoadPost при необходимости, project-session E2E/diagnostic, docs/FIXLOG. Без нового root/panel API, plugin pin/SDK изменений, timer recovery или собственного language backend.
