# Proposal

## Why

IDE-146/WF-14: выделение должно выполняться в активной встроенной консоли.
Сейчас Visual Ctrl+Enter в config/keymaps.lua вызывает внешний pwsh через
:write !, игнорируя ToggleTerm, выбранный shell, видимость и текущую сессию.

## What Changes

- Visual Space t e и прежний Ctrl+Enter используют единый native selection route.
- Текст получает Neovim getregion, выполнение — public ToggleTerm open/send;
  последняя активная обычная консоль переиспользуется и раскрывается; одна UI
  ссылка на native instance сохраняет active choice после hide/TermClose.
- При отсутствии консоли создаётся штатная с текущим cwd/shell policy.
  Живой job/REPL, история, файл и registers сохраняются.
- Завершённая консоль раскрывается с понятным предупреждением, без потери
  истории/неявного перезапуска. Private hidden terminals не выбираются.
- Native E2E Windows/Ubuntu, guides/FIXLOG/roadmap; physical Mac/Omarchy отдельно.

## Capabilities

### New Capabilities

- `terminal-selection`: IDE-PANEL-30, точное выделение → active managed Terminal.

### Modified Capabilities

Нет root IDE baseline; main specs WezTerm/macOS не меняются. IDE-PANEL-19
сохраняет shell policy; существующий Ctrl+Enter transport не меняется.

## Impact

config/keymaps.lua, registered terminal-selection E2E, terminal/keyboard guides,
IDE-146/WF-14, FIXLOG297/HISTORY/commands205. Pins/SDK/backports неизменны.
