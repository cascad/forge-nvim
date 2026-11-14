## Why

IDE-138 ещё требует ручной RuntimePath/URL. Один монолит всех языков заставляет Custom скачивать лишнее. Нужна автоматическая доставка Core и только выбранных модулей, общая для Windows/Linux/macOS.

## What Changes

- Runtime catalog platform/component/URL/SHA256 и выбор по прежней canonical component closure.
- Core содержит supported Neovim; дополнительные модули собираются в private staging после проверки manifest/hash/platform и отсутствия конфликтов.
- Developer packager выпускает Core либо component archive/receipt; установка использует готовые артефакты без host package managers/компилятора.
- Сохраняется явный RuntimePath/RuntimeArchiveUrl API. Missing catalog entry даёт точный отказ до backend/target, без молчаливого системного fallback.
- Native HTTP/install/launch/repeat/failure регресс с готовым Neovim и настоящим дополнительным executable; журналы и понятные команды.

## Capabilities

### New Capabilities

- `runtime-delivery`: IDE-BOOT-14, автоматическая доставка и сборка выбранных private SDK модулей.

### Modified Capabilities

Нет. Существующие private install/UI контракты сохраняются; это новый путь без explicit runtime args.

## Impact

Native UI resolver, private PS/Bash/Lua backend, runtime packager/catalog. Не добавляются LSP, global package managers, Docker/WSL управление или новые SDK patches. Полный набор настоящих language bundles, actual Mason readiness, опубликованные assets и native Mac остаются отдельными gates; этот срез проверяет доставку и native сборку, а не объявляет весь Default готовым.
