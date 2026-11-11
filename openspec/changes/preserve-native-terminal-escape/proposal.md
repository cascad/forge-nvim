# Proposal

## Why

IDE-023 воспроизведён на6dea7b8: после `:terminal echo` редактор уже в terminal-normal (`nt`), normal shortcut Ctrl-\\ открывает новый ToggleTerm вместо безопасного native Ctrl-\\ Ctrl-n. В terminal-input (`t`) chord работает и при загруженном plugin; причина в normal mapping plugins/terminal.lua, не в terminal open_mapping. Новый IDE-PANEL-16 закрепляет границу буфера и сохранение terminal/DAP состояния.

## What Changes

- В terminal buffer normal Ctrl-\\ сохраняет native prefix; повторный Ctrl-\\ Ctrl-n не открывает/скрывает окна и не создаёт process/job.
- В остальных normal buffers прежний Ctrl-\\ toggle сохраняется; Ctrl-t и Space tt остаются путями управления ToggleTerm, включая terminal-normal.
- Real E2E для exited/native live/cold-loaded/managed terminal, aliases из кода и настоящего paused DAP PTY; источник до исправления даёт native RED.
- Уточнить историческое описание причины, записать Windows/Ubuntu evidence/историю; Mac/GUI без запуска не PASS.

## Capabilities

### New Capabilities

- `terminal-escape`: IDE-PANEL-16, native escape в terminal buffer.

### Modified Capabilities

Нет: main specs пока WezTerm, прежние IDE-PANEL-1/2 сохраняются, D*/P*/m* aliases не затрагиваются.

## Impact

Один shortcut plugins/terminal.lua, native terminal E2E/fixture/registry и docs/FIXLOG. Без новых controllers/autocmd/state/timers, plugin/SDK обновлений, shell changes или Docker/WSL lifecycle. Terminal/Trouble общий UI остаётся следующим самостоятельным шагом.
