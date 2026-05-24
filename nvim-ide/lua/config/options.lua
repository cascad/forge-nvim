-- Vim options. Pure stdlib, no plugin dependencies.

local opt = vim.opt

-- Line numbers
opt.number         = true
opt.relativenumber = true
opt.signcolumn     = "yes"   -- always show signcolumn to avoid text shifts
opt.cursorline     = true
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false

-- Indent
opt.expandtab     = true
opt.shiftwidth    = 4
opt.tabstop       = 4
opt.softtabstop   = 4
opt.smartindent   = true
opt.breakindent   = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- UI
opt.termguicolors = true
opt.showmode      = false   -- lualine shows the mode
opt.splitright    = true
opt.splitbelow    = true
opt.splitkeep     = "screen"
opt.cmdheight     = 1
opt.pumheight     = 12
opt.pumblend      = 10
opt.winblend      = 0
opt.laststatus    = 3       -- single global statusline
opt.fillchars     = {
    fold    = " ",
    foldsep = " ",
    diff    = "/",
    eob     = " ",
}
opt.list      = true
opt.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" }

-- Editing
opt.mouse         = "a"
opt.clipboard     = "unnamedplus"
opt.undofile      = true

-- Windows clipboard: win32yank.exe (его выбирает Neovim по умолчанию,
-- если он в PATH) часто падает на не-UTF8 / CRLF, особенно на
-- многострочных yank'ах с кириллицей в путях:
--   "stream did not contain valid UTF-8".
-- Переключаемся на встроенные `clip.exe` (copy) и PowerShell (paste).
-- `clip.exe` принимает любые байты, PowerShell снимает CR.
if vim.fn.has("win32") == 1 then
    local pwsh_paste = {
        "powershell.exe",
        "-NoLogo",
        "-NoProfile",
        "-Command",
        "[Console]::Out.Write((Get-Clipboard -Raw).Replace(\"`r\", ''))",
    }
    vim.g.clipboard = {
        name = "win-clip-pwsh",
        copy = {
            ["+"] = { "clip.exe" },
            ["*"] = { "clip.exe" },
        },
        paste = {
            ["+"] = pwsh_paste,
            ["*"] = pwsh_paste,
        },
        cache_enabled = 0,
    }
end
opt.undolevels    = 10000
opt.swapfile      = false
opt.backup        = false
opt.confirm       = true
opt.updatetime    = 250    -- CursorHold latency, used by gitsigns/lsp
opt.timeoutlen    = 400    -- which-key popup latency
opt.completeopt   = { "menu", "menuone", "noselect" }
opt.virtualedit   = "block"

-- Folds — driven by treesitter, default to expanded.
opt.foldmethod = "expr"
opt.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = true
opt.foldlevel  = 99

-- Sessions — what `:mksession` / persistence.nvim persists.
opt.sessionoptions = {
    "buffers", "curdir", "tabpages", "winsize",
    "help", "globals", "skiprtp", "folds",
}

-- Spelling — off by default, toggle per-buffer.
opt.spelllang = { "en", "ru" }
opt.spell     = false

-- Diagnostics — virtual_text + signs + underline, sorted by severity.
vim.diagnostic.config({
    severity_sort = true,
    underline     = true,
    update_in_insert = false,
    virtual_text  = {
        prefix = "●",
        spacing = 2,
    },
    float = {
        border = "rounded",
        source = true,
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN]  = "",
            [vim.diagnostic.severity.INFO]  = "",
            [vim.diagnostic.severity.HINT]  = "󰌶",
        },
    },
})
