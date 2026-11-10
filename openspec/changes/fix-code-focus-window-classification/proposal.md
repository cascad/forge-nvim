# Proposal

## Why

IDE-088, native Windows/Ubuntu на source 7fe45bc: PTY в первом окне, отдельный main существует; F7 переводит в main, Space m d открывает Debug и уводит фокус в PTY. activities.find_code_window не исключает terminal/float. Обзор CODE_WINDOW_REVIEW и FIXLOG §155 доказали расхождение с намерением IDE-PANEL-2/11 вернуть фокус в код; новый IDE-PANEL-12 уточняет focus-only границу.

## What Changes

- Focus-only поиск использует ordinary main predicate с сохранением прежних дополнительных tool исключений.
- Find/focus без кандидата возвращает отсутствие результата, не создаёт split. Создание по Space w 0 остаётся в state; F7 только выбирает существующее окно через ide.buffers.
- Native регрессии terminal-first + Debug View, terminal-only и float-only; прежние DAP/Output/language проверки повторяются Windows/Ubuntu.

## Capabilities

### New Capabilities

- `ide-code-focus`: IDE-PANEL-12, обычное окно кода для focus-only поиска.

### Modified Capabilities

Нет: main nvim baseline ещё не снят, прежние delta требования остаются в своих changes.

## Impact

Узкое изменение ide/activities.lua, E2E/registry и руководства/история. Session cleanup, tool таблицы, guard relocation, создание main, SDK/pins не меняются. Mac/native gate остаётся открытым.
