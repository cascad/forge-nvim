# Proposal

## Why

WF-01 требует рабочего места после повторного открытия проекта. Files уже
сохраняется (§205), но Logs теряет видимость, размеры и фильтры: SavePre
закрывает tool views, session_files сохраняет только дерево.

## What Changes

- Сохранять Logs по code tabpages: видимость, высоту и позицию просмотра.
- Возвращать общий native источник/уровень/текстовый фильтр Logs для проекта.
- Поддержать quit/relaunch и A→B→A, малый UI, прежние Files/legacy sessions.
- Проверить настоящими PTY/keyboard E2E и записать историю результата.

## Capabilities

### New Capabilities

- `logs-session-view`: IDE-LOG-5, рабочий вид общей консоли в проектной сессии.

### Modified Capabilities

Нет. IDE-PANEL-25 Files сохраняется.

## Impact

Существующие session views и Logs, Persistence hooks, native Edgy resize.
Только данные представления; backend/процессы/plugins/pins прежние. Остальные
панели WF-01 — следующие самостоятельные срезы, не часть этой реализации.
