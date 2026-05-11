-- Все vim.opt.* — здесь. Маппинги в keymaps.lua, плагины в plugins\.

local opt = vim.opt
local ru_keys = require("config.ru_keys")

-- Set this to true after configuring your terminal font to a Nerd Font
-- variant, for example "CaskaydiaCove Nerd Font" or "JetBrainsMono Nerd Font".
-- Neovim cannot bundle terminal glyphs by itself; the terminal font decides
-- whether codicons/devicons render as icons or replacement diamonds.
vim.g.have_nerd_font = vim.g.have_nerd_font or false

opt.number = true
opt.relativenumber = true
-- Две колонки номеров одновременно:
--   слева абсолютный номер строки в файле (%l), справа относительный (%r).
-- Нативные number+relativenumber показывают абсолютный только на текущей
-- строке (hybrid-mode), поэтому используем 'statuscolumn'.
--
-- Формат: <signs><fold> <abs:4> | <rel:3>
-- ASCII-разделитель `|` вместо `│`, потому что некоторые шрифты/терминалы
-- режут box-drawing глифы по высоте, и колонка визуально схлопывается в одну.
local statuscolumn = "%s%C %4{v:lnum} %=%3{v:relnum} "

-- Применяем ко всем буферам кроме спец-плагинных (neo-tree, dap-ui, alpha,
-- lazy, mason, trouble и т.п.) — у них собственный gutter, и наш statuscolumn
-- ломает их выравнивание.
local excluded_ft = {
    ["neo-tree"]      = true,
    ["dap-repl"]      = true,
    ["dap-view"]      = true,
    ["dap-view-term"] = true,
    ["dap-view-help"] = true,
    ["OverseerList"]  = true,
    ["overseer"]      = true,
    ["overseer-list"] = true,
    ["lazy"]          = true,
    ["mason"]         = true,
    ["trouble"]       = true,
    ["alpha"]         = true,
    ["help"]          = true,
    ["man"]           = true,
    ["qf"]            = true,
    ["aerial"]        = true,
    ["TelescopePrompt"] = true,
    ["TelescopeResults"] = true,
}
local excluded_bt = {
    ["nofile"]   = true,
    ["prompt"]   = true,
    ["terminal"] = true,
    ["quickfix"] = true,
}

local function apply_statuscolumn(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local ft  = vim.bo[buf].filetype
    local bt  = vim.bo[buf].buftype
    if excluded_ft[ft] or excluded_bt[bt] then
        vim.wo[win].statuscolumn = ""
    else
        vim.wo[win].statuscolumn = statuscolumn
    end
end

opt.statuscolumn = statuscolumn
for _, w in ipairs(vim.api.nvim_list_wins()) do apply_statuscolumn(w) end

vim.api.nvim_create_autocmd(
    { "WinNew", "BufWinEnter", "FileType", "BufEnter" },
    {
        group = vim.api.nvim_create_augroup("UserLineNumberColumns", { clear = true }),
        callback = function()
            apply_statuscolumn(vim.api.nvim_get_current_win())
        end,
    }
)

local wrapped_output_ft = {
    ["dap-repl"] = true,
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["OverseerList"] = true,
    ["overseer"] = true,
    ["overseer-list"] = true,
    ["neotest-output-panel"] = true,
}

local function apply_output_wrap(win)
    if win and not vim.api.nvim_win_is_valid(win) then return end
    local wins = win and { win } or vim.api.nvim_tabpage_list_wins(0)

    for _, w in ipairs(wins) do
        if vim.api.nvim_win_is_valid(w) then
            local buf = vim.api.nvim_win_get_buf(w)
            if wrapped_output_ft[vim.bo[buf].filetype] then
                vim.wo[w].wrap = true
                vim.wo[w].linebreak = true
                vim.wo[w].breakindent = true
                vim.wo[w].showbreak = "  "
            end
        end
    end
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
    group = vim.api.nvim_create_augroup("UserOutputWrap", { clear = true }),
    callback = function()
        apply_output_wrap()
    end,
})
opt.cursorline = true
opt.cursorlineopt = "number,line"  -- подсветить и номер строки, и строку
opt.signcolumn = "yes"

-- Курсор: явная форма + blink, чтобы всегда было видно где он. На
-- Windows Terminal / WezTerm / Alacritty эта строка читается; в
-- Cursor highlight (lua\plugins\ui.lua → catppuccin override) задан
-- яркий персиковый цвет, чтобы курсор контрастировал с фоном.
local cursor_shapes = {
    "n-v-c-sm:block-Cursor",                 -- normal/visual/cmd: блок
    "i-ci-ve:ver25-Cursor",                  -- insert: вертикальная палка 25%
    "r-cr-o:hor20-Cursor",                   -- replace/operator: горизонтальная 20%
    "a:blinkwait200-blinkon300-blinkoff200", -- мерцание во всех режимах
}
opt.scrolloff = 999          -- курсор всегда по центру (settings.json: cursorSurroundingLines:999)
local cursor_shapes_value = table.concat(cursor_shapes, ",")
local last_cursor_shape_refresh = -1000

local function apply_cursor_shapes(force)
    local now = (vim.uv or vim.loop).now()
    if not force and now - last_cursor_shape_refresh < 120 then
        return
    end
    last_cursor_shape_refresh = now

    -- Force a resend to terminals/IME layers that keep an insert-style cursor
    -- after focus, window, or keyboard-layout changes.
    vim.o.guicursor = ""
    vim.o.guicursor = cursor_shapes_value
end

apply_cursor_shapes()
vim.api.nvim_create_autocmd(
    {
        "VimEnter",
        "UIEnter",
        "ModeChanged",
        "InsertEnter",
        "InsertLeave",
        "CmdlineEnter",
        "CmdlineLeave",
        "FocusGained",
        "WinEnter",
        "BufEnter",
        "TabEnter",
        "TermEnter",
        "TermLeave",
        "VimResume",
        "SafeState",
    },
    {
        group = vim.api.nvim_create_augroup("UserCursorShape", { clear = true }),
        desc = "Keep terminal cursor shape tied to the Neovim mode, not the keyboard layout",
        callback = function(args)
            apply_cursor_shapes(args.event ~= "SafeState")
        end,
    }
)
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true
opt.colorcolumn = "100,120"  -- как helix rulers

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.autoindent = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.langmap = ru_keys.langmap()
opt.langremap = false

opt.splitright = true
opt.splitbelow = true

opt.termguicolors = true     -- catppuccin требует true-color
opt.background = "dark"

opt.mouse = "a"
opt.clipboard = "unnamedplus" -- yank всегда в системный буфер (vim.overrideCopy:false аналог)

opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.updatetime = 200         -- настолько же, насколько autoSaveDelay
opt.timeoutlen = 400         -- быстрее срабатывает which-key

-- Project sessions are saved by persistence.nvim via native :mksession.
-- Keep this explicit: persistence.nvim does not own 'sessionoptions' itself.
opt.sessionoptions = {
    "buffers",
    "curdir",
    "folds",
    "help",
    "localoptions",
    "tabpages",
    "winsize",
}
opt.viewoptions = { "folds", "cursor", "curdir" }

local function can_persist_view(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then return false end
    if vim.bo[buf].buftype ~= "" then return false end
    if vim.api.nvim_buf_get_name(buf) == "" then return false end
    return true
end

vim.api.nvim_create_autocmd("BufWinLeave", {
    group = vim.api.nvim_create_augroup("UserFileViews", { clear = true }),
    callback = function(args)
        if can_persist_view(args.buf) then
            pcall(vim.cmd, "silent! mkview")
        end
    end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("UserFileViewsLoad", { clear = true }),
    callback = function(args)
        if can_persist_view(args.buf) then
            pcall(vim.cmd, "silent! loadview")
        end
    end,
})

opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 12

opt.wildmenu = true
opt.wildmode = { "longest:full", "full" }
opt.wildoptions = { "pum", "tagfile" }
opt.wildignorecase = true
-- <Tab> is mapped in command-line mode, so it cannot be used directly as the
-- built-in wildchar. wildcharm gives mappings a native way to trigger the same
-- completion, which keeps path prompts like "Open project path:" ergonomic.
opt.wildcharm = 26 -- Ctrl+Z

opt.list = true
opt.listchars = { tab = "→ ", nbsp = "⍽", trail = "·" }

opt.fillchars = { eob = " " } -- без ~ на пустых строках

opt.shortmess:append("c")
opt.shortmess:append("I")

opt.confirm = true            -- спрашивать вместо ошибки на :q с unsaved
opt.laststatus = 3            -- одна глобальная statusline

-- selection=exclusive — это про visual mode без захвата \n при `$`.
-- В Neovim это поведение и без того по умолчанию для большинства операций
-- через текст-объекты. Дополнительно перевешиваем `$` в visual на `g_`
-- (как vim.visualModeKeyBindings из settings.json) — см. keymaps.lua.

-- Folds через treesitter (включаются в plugins\treesitter.lua),
-- здесь только дефолты, чтобы при первом старте без TS не было воя.
opt.foldmethod = "indent"
opt.foldlevelstart = 99

-- Под Windows shell оставляем дефолтным cmd.exe — pwsh подключаем
-- точечно для async-команд (dap, conform). Менять глобально опасно:
-- многие плагины передают аргументы в cmd-стиле.

-- Большие файлы: settings.json: largeFileOptimizations:false ⇒ не ломаем
-- LSP/treesitter на больших файлах. Просто не отключаем оптимизации.
