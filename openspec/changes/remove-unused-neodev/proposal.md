# Proposal

## Why

IDE-080: neodev остался отдельным ft=lua plugin после перехода на native
vim.lsp.config. Его pinned hook работает через legacy lspconfig.util.on_setup;
текущий LuaLS уже получает VIMRUNTIME в on_init (IDE-BOOT-31).
Удаление допустимо только после настоящего LuaLS control до/после.

## What Changes

- Registered native Lua E2E: диагностика/edit/save, Neovim API completion/hover,
  .luarc.json и .luarc.jsonc с собственной library.
- Source control с neodev, затем удаление только его spec/pin/source entry,
  если результат и native settings сохраняются. Остальные pins не обновлять.
- Обновить текущий inventory/review/очередь и историю; Windows/Ubuntu affected
  packet после реализации, macOS/Omarchy оставить явно непроверенными.

## Capabilities

### New Capabilities

Нет: skip_specs=true, cleanup зависимости с сохранением IDE-BOOT-31.

### Modified Capabilities

Нет. При обнаружении роли neodev удаление отменяется, результат документируется.

## Impact

lsp.lua, lazy-lock.json, test plugin sources, новый Lua native E2E/registry,
docs/inventory/FIXLOG298/HISTORY/commands206. Языковые SDK и backports прежние.
SQL и DAP входят в другие пункты очереди.
