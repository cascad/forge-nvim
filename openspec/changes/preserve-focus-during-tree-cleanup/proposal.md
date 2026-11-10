# Proposal

## Why

IDE-084 нарушает намерение IDE-PANEL-3: после первого Outline символы видны,
но фокус уходит в код. Native trace выявил поздний Neo-tree navigate после
смены слота: forge/neo_tree_lifecycle.lua закрывает лишнее дерево, Edgy on_hide
при уничтоженном окне вызывает goto_main. Windows: 1/3 свежих profiles,
последующие 24 наблюдения сохраняют go. Новый IDE-PANEL-10 фиксирует границу
фонового cleanup и пользовательского фокуса; существующей main capability нет.

## What Changes

- Сохранять действующий фокус при закрытии позднего окна дерева; если само
  дерево временно забрало фокус, вернуть штатное предыдущее окно backend.
- Добавить native E2E с реальным gopls и поздним настоящим Neo-tree open,
  проверяя Outline и явно выбранное окно кода.
- Сохранить diagnostic trace, причину, команды и платформенные gates.

## Capabilities

### New Capabilities
- `panel-focus-lifecycle`: IDE-PANEL-10, фоновые операции закрытия не отменяют выбор окна.

### Modified Capabilities

Нет изменений main specs. IDE-PANEL-3 пока находится в отдельном открытом change.

## Impact

Узкий lifecycle guard, tests/diagnostics/E2E/registry и docs/history.
Пины, upstream исходники, LSP и общий panel framework прежние.
Windows/Ubuntu native checks; macOS/GUI отдельный gate.
