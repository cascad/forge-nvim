# Proposal

## Why

Managed parsers stage вызывает `ForgeTreesitterInstall` и требует tree-sitter/C-компилятор у пользователя. Это оставшийся пробел Core из RELEASE_INVENTORY: готовая IDE должна получать native parser libraries, а сборочные SDK нужны только publisher. Новый контракт — IDE-BOOT-24.

## What Changes

- Core publisher упаковывает готовый native Neovim и проверенный Treesitter site с существующим составом грамматик; не собирает и не устанавливает SDK.
- Managed setup проверяет доставленные библиотеки и queries без скачивания/сборки. Неполный или несовместимый набор не заменяет прежний kit.
- Runtime использует доставленный site штатным runtimepath; обычная неменеджерская конфигурация сохраняет существующую явную команду установки парсеров.

## Capabilities

### New Capabilities

- `managed-parser-runtime`: готовые native parsers и проверка их фактической загрузки в managed IDE.

### Modified Capabilities

Нет; baseline specs пока описывают WezTerm/macOS installer.

## Impact

Core publisher, setup-stage, runtimepath, targeted native delivery E2E и история. Состав plugins/parsers, lazy-lock, backports и обычные SDK не меняются. Git/search, Terminal, full Default и публикация — следующие части существующей очереди.
