# Proposal

## Why

WF-01 уже возвращает Files и Logs, но выбранный вместо Files Outline пропадает
после перезапуска. Native Aerial должен снова открыть символы восстановленного
файла с прежней шириной, без нового layout owner или смены follow-поведения.

## What Changes

- Сохранять видимость и ширину Outline по вкладкам/проектам рядом с Files/Logs.
- Поддержать quit/relaunch, A→B→A, скрытую панель и меньший UI.
- Оставить native символы/выбор позиции по восстановленному code cursor.
- Объединить одинаковый Edgy resize для Logs/Outline внутри session_views.

## Capabilities

### New Capabilities

- `outline-session-view`: IDE-PANEL-26, открытость и геометрия Outline в сессии.

### Modified Capabilities

Нет. Files/Logs прежние; arbitrary scroll/folds Outline и Tests отдельно.

## Impact

Существующий sidecar/Edgy/Aerial API, один native E2E и регресс прежних panels.
Plugins/pins/backend/provider не меняются, процессы/инструменты не запускаются
для восстановления представления. Native language provider может работать,
как при обычном открытии исходника.
