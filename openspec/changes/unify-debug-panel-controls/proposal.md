## Why

IDE-005/009: переходы между кодом, Locals и Output разбросаны по D*/P*/m*,
постоянные панели не дают общего маршрута отмены/скрытия и подсказки. Начинаем
пилот Run & Debug из этапа 3. Владелец выбрал Space w как общий раздел окон;
существующие сочетания сохраняются. Новые требования IDE-PANEL-1/2.

## What Changes

- Space w h/j/k/l — соседнее окно; 0 — код; d — Locals; c — Output;
  q — скрыть текущую debug-панель; z — развернуть/вернуть; ? — помощь.
- В debug-панелях normal q скрывает, Esc возвращает в код или из zoom,
  ? показывает подсказку. Insert/terminal ввод печатных клавиш сохраняется.
- Видимый индикатор фокуса в заголовке. Zoom показывает тот же буфер
  поверх раскладки и восстанавливает исходное окно без закрытия соседей.
- Все действия UI сохраняют paused-сессию, вывод и breakpoints; обычные
  действия списка/дерева остаются у backend. Алиасы D*/P*/m* не удаляются.
- Настоящие Go/Delve и editor E2E Windows/Ubuntu; Mac/физические клавиши отдельно.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-1/2, общий маршрут фокуса и пилот debug UI.

### Modified Capabilities

Нет: baseline редактора ещё не снята; DAP output/eval — соседние контракты.

## Impact

ide/controls.lua, ide/dap.lua, config/keymaps.lua, setup IDE,
tests/e2e/fixture/registry, docs/FIXLOG/хронология/план. Новых плагинов и
OS-веток нет; остальные панели будут подключаться после пилота.
