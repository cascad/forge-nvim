# Tasks

## 1. IDE tools

- [x] 1.1 Подключить LSP/formatters/DAP к общему resolver через public APIs; сохранить native roots/env и passive startup. Gotestsum отложен до upstream API, native tests прежние. Проверка: native Go/Rust path E2E Windows/Ubuntu, без SDK installs/patches.
- [x] 1.2 Добавить регрессы custom/project/user/invalid paths, formatter context и DAP; сохранить существующие workspace/debug/passive controls. Проверка: целевой набор одной итерацией, repeat лишь при изменении/отказе; Mac отдельно.
- [x] 1.3 Описать поддержанные keys/SDK границу, FIXLOG `Спека: IDE-BOOT-36 (ADDED)`, history/commands/roadmap. Проверка: strict/diff/exact index/frozen/prefix guards, local commit.
