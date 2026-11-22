## Why

IDE-155. `Ctrl+P` из Files находит нужный файл, но `Enter` оставляет открытый
документ прежним. Telescope возвращается в окно запуска и вызывает `edit`.
Окно Files закреплено `winfixbuf`, а Telescope подавляет отказ этого `edit`.

## What Changes

- Выбирать окно кода штатным callback Telescope при открытии результата.
- Сохранять активный split, если поиск запущен из кода, и окно панели при поиске из него.
- Покрыть оба маршрута клавишами `Ctrl+P` и `Enter` в настоящем редакторе.

## Capabilities

### New Capabilities

- `file-search-editor-target`

### Modified Capabilities

Нет.

## Impact

Настройка Telescope, приёмочный E2E и справка. Выбор команды и отмена поиска
остаются штатными действиями Telescope.
