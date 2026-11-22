## Why

IDE-149: отдельные списки filetypes в buffers/state/marks/panel_guard/activities
дают разную классификацию окна. Guard чинит только named-file leakage и может
схлопнуть нормальные editor splits по winfix-эвристике. Help явно сохраняется
через sessionoptions=help. Одна галочка winfixbuf ломает Neo-tree source switch.
Владелец поручил выполнить этот этап. Контракт IDE-PANEL-32 отделяет editor,
tool и transient, допускает штатные переходы и исключает временные окна из restore.

## What Changes

- Единая классификация/owner/lifetime по declarations registry.
- Native winfixbuf у tool views; разрешённые backend transitions через общий
  механизм и события backend, без подмены глобальных Neovim API.
- Навигация в файлы идёт в editor, защитный repair сохраняет текст и splits.
- Сессии сохраняют документы и разрешённые view snapshots, не Help/input/menu;
  старые session scripts очищаются после загрузки.
- Native regression разрешённых переходов, навигации, job safety и restore.

## Capabilities

### New Capabilities
- `window-ownership`: IDE-PANEL-32.

### Modified Capabilities
Нет main IDE baseline; требования остаются в delta до отдельного archive.

## Impact

Registry/marks/panel_guard, общие editor predicates, backend lifecycle adapters,
session hooks и native E2E. Пины, SDK, терминальный протокол и новый window manager
не входят. Если потребуется систематически переписывать backend, этап не закрывать
условным PASS — остановиться и показать конкретное ограничение.
