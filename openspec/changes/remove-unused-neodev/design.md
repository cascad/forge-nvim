# Design

## Context

См. proposal. Native LuaLS on_init уже исключает plugin-wide indexing и
уважает явные .luarc.json/jsonc. Legacy hook neodev не вызывается native API.
Для control найден подготовленный upstream LuaLS3.19.2, Windows executable;
пользовательские SDK/профили не нужны.

## Goals / Non-Goals

Goals: доказать сохранение Lua workflow и убрать неработающую зависимость.
Non-Goals: обновление LuaLS/остальных plugins, добавление lazydev, замена
LuaLS settings, platform shell/SDK changes, SQL/DAP рефакторинг в этом change.

## Decisions

- Настоящий editor RPC и native LuaLS, private profile и logpath; без API mocks.
  Baseline с загруженным neodev и target без него проверяют одинаковые запросы
  и settings. Cleanup не требует искусственного source RED.
- Обычный Lua workspace: ровно VIMRUNTIME library, реальные diagnostics,
  completion/hover Neovim API и edit/save. Explicit luarc/jsonc: внешний
  fixture module и hover его документации, без подмены library в on_init.
- После control удалить только dependency/spec/catalog row. Plugins manifest
  пересобрать в собственной копии prepared cache; user cache не удалять.
- Один affected packet Windows/Ubuntu после готовности; повторять лишь отказы
  или затронутые поздней правкой случаи. Mac/Omarchy отдельно.

## Risks / Trade-offs

Порядок загрузки legacy plugin → baseline фиксирует package.loaded и native
settings, target доказывает отсутствие plugin. LuaLS async readiness → ждать
реальные diagnostics/responses. Cache lock mismatch → явный private manifest
для66 pins, остальные revisions должны совпасть с source.
