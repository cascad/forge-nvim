# Proposal

## Why

IDE-132: владелец видит задержку до секунды при раскрытии Files. В pinned
Neo-tree `filesystem.async_directory_scan="auto"` оставляет ручной `l`/Enter
синхронным: `toggle_directory` передаёт `false` в `fs_scan.get_items`.
IDE-FILE-6 добавляет требование отзывчивого ввода при незавершённом чтении.
Конкретная стоимость на большом рабочем проекте пока не измерена.

## What Changes

- Применить штатный режим Neo-tree `always` для чтения Files.
- Постоянный native E2E: ручное раскрытие, удержанный настоящий IO callback,
  переключение в код и ввод до завершения чтения, затем открытие дочернего файла.
- Сохранить source RED и проверки существующего порядка обновления дерева.

## Capabilities

### New Capabilities

- `file-explorer-responsiveness`: отзывчивость Files при ручном раскрытии.

### Modified Capabilities

Нет; baseline nvim_forge ещё не снята. Прежний IDE-FILE-5 сохраняется.

## Impact

`plugins/neo-tree.lua`, существующий file-scan-order E2E и его IO observer,
документация и история. Общая настройка для Windows/macOS/Ubuntu; SDK,
lazy-lock и исходники плагина прежние.
