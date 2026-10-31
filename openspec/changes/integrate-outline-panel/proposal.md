# Proposal

## Why

IDE-008 требует Outline слева и управления без мыши. Сейчас Aerial описан
дважды (`plugins/ide.lua`, `plugins/outline.lua`), со взаимоисключающими
стороной и приоритетами backend. Space l o / s o обходят `ide.state`, поэтому
могут оставить дерево файлов вместе с Outline при одном логическом left-слоте.
Общие q/Esc/zoom/help из пилота Debug на Outline ещё не распространяются.
Контракт этого изменения: IDE-PANEL-3, продолжение принятого Space w.

## What Changes

- Один модуль Aerial, LSP с Treesitter fallback, без автоматических установок.
- Старые Space l o / s o переключают компонент Outline через менеджер слотов;
  Space p o сохраняет назначение раскладки. Space w a открывает/фокусирует Outline
  (Space w o уже занят прежним «оставить одно окно»).
- Общие фокус, q/Esc, помощь и zoom; штатная навигация по символам и раскрытие.
- Настоящие editor E2E: символы, Enter, переключение файлов/дерева, zoom/помощь,
  файл без backend; прогон Windows и Ubuntu, команда владельцу для Mac.
- Найденные регрессом переходы Neo-tree: устаревший tree-буфер и поздний
  navigate после замены левого компонента; q после обычного AerialOpen.

## Capabilities

### New Capabilities

- `outline-panel`: структура текущего файла слева и общий маршрут управления.

### Modified Capabilities

Нет. IDE-PANEL-1/2 из активного `unify-debug-panel-controls` сохраняются.

## Impact

`plugins/outline.lua`, `plugins/ide.lua`, `plugins/neo-tree.lua`,
`forge/neo_tree_lifecycle.lua`, `ide/controls.lua`, keymaps,
editor E2E/реестр, инструкции, FIXLOG и хронология. Новых зависимостей и
ветвлений по ОС нет. Обновление lock-файла не требуется.
