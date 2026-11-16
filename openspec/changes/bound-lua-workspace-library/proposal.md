# Proposal

## Why

IDE-138 actual Core consumer (FIXLOG260) получил LuaLS attach, но type diagnostic не пришёл за20s. lsp.lua добавляет весь runtimepath в workspace.library; native server log подтверждает обход Lua библиотек plugins. Документация закреплённого nvim-lspconfig прямо предупреждает о замедлении этого варианта. Новый LSP/новые зависимости не нужны.

## What Changes

- Убрать все plugins из автоматически добавляемых Lua libraries.
- Штатный on_init добавляет только Neovim runtime, если проект не имеет собственной .luarc.json/jsonc. При явной настройке проекта library не навязывается.
- Довести actual Core diagnostics/edit/save/restart и покрыть оба варианта project config native LSP тестом.

## Capabilities

### New Capabilities

- `lua-workspace-library`: IDE-BOOT-31, ограниченная automatic library и приоритет project settings.

### Modified Capabilities

Нет; baseline phase1 не синхронизируется.

## Impact

Точечная настройка существующего lua_ls в plugins/lsp.lua, native consumer regression/docs/FIXLOG261. Pins, SDKs, Mason catalog и Neodev не меняются.
