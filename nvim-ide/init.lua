-- nvim-ide based Neovim distribution.
--
-- Entry point. Order matters:
--   1) leader keys must be set BEFORE any plugin spec is evaluated,
--      otherwise lazy.nvim binds `<leader>X` mappings against the
--      default `\` leader.
--   2) options/keymaps/autocmds are pure-vim and have no plugin deps.
--   3) `config.lazy` bootstraps lazy.nvim and imports `plugins/`.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Disable vim.loader byte-code cache during the active development of
-- this config. The cache caches by file mtime, but on Windows mtime
-- can be missed across rapid edit-run cycles, leading to stale bytecode
-- and confusing errors that refer to lines that no longer exist.
-- Re-enable (or just delete this line) once the config stabilises.
vim.loader.enable(false)

-- Disable unused providers — speeds up startup and silences healthcheck
-- noise. Re-enable per-provider if you need it.
vim.g.loaded_perl_provider   = 0
vim.g.loaded_ruby_provider   = 0
vim.g.loaded_node_provider   = 0
vim.g.loaded_python3_provider = 0

vim.g.have_nerd_font = true

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
