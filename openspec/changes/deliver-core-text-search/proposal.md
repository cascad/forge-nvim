# Proposal

## Why

В очереди Core (§250–255) ещё отсутствует ripgrep: готовый managed runtime без системного `rg` не обеспечивает штатные Telescope find_files/live_grep. IDE-138 требует доставку всех частей IDE одной установкой; новый контракт IDE-BOOT-26 закрывает именно native text search.

## What Changes

- Core publisher включает готовый ripgrep15.2.0 с pinned official archive SHA, native version probe и лицензиями.
- Используется прежний runtime catalog/transport/launcher PATH; SDK пользователя и global PATH не меняются.
- Native E2E проходит установку и настоящий Telescope поиск по имени/содержимому с открытием результата без системного rg/fd.

## Capabilities

### New Capabilities

- `managed-search-runtime`: поставка native поиска в составе Core и работа штатного picker.

### Modified Capabilities

Нет; существующий baseline посвящён WezTerm/macOS installer.

## Impact

Publisher Core и подготовка готового release asset, metadata/license inventory, targeted delivery E2E и история. Состав plugins/языков/parsers не меняется. Git policy обсуждается отдельно; Git, Terminal, full Default и публикация не входят в этот срез.
