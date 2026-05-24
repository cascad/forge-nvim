-- ldelossa/nvim-ide — the VSCode-like panel framework.
--
-- This module owns:
--   * Left  panel = "explorer" group (Explorer, Outline, BufferList, ...)
--   * Right panel = "git"      group (Changes, Commits, Branches, Timeline)
--   * Bottom panel = "terminal" group (TerminalBrowser)
--
-- All sibling components inside each group start hidden. The `show()` helper
-- below flips visibility so a panel acts like a VSCode Activity Bar:
-- selecting a section reveals only that section.

local function patch_workspace_registry()
    -- Upstream throws on duplicate `register()` calls for the same tab,
    -- but nvim-ide's own controller does call it twice during VimEnter.
    -- Make it idempotent so re-attaching nvim-ide to an existing tab
    -- (e.g. after `:Lazy reload`) returns the existing workspace.
    local ok, registry = pcall(require, "ide.workspaces.workspace_registry")
    if not ok or registry.__forge_patched then return end
    local original = registry.register
    registry.register = function(ws)
        if registry.get_workspace then
            local existing = registry.get_workspace(ws.tab)
            if existing then return existing end
        end
        return original(ws)
    end
    registry.__forge_patched = true
end

local function patch_explorer_prompts()
    -- Чиним два бага в upstream Prompts:
    --
    -- 1) `get_file_rename` — не проверяет nil-input. `vim.ui.input` при
    --    <Esc> зовёт callback с nil, в filenode:rename конкатенация
    --    падает.  Лечим guard'ом: nil / "" → тихо вернуться.
    --
    -- 2) `should_delete` — внутри делает `input:lower() ~= "y"`,
    --    что крашится на <Esc> (`nil:lower()`). Плюс пользовательский
    --    callback зовётся БЕЗ аргументов — общий guard к нему неприменим
    --    (он сожрёт удаление, потому что увидит `input == nil`).
    --    Заменяем на корректную реализацию.
    local ok, prompts = pcall(require, "ide.components.explorer.prompts")
    if not ok or prompts.__forge_patched then return end

    -- --- (1) get_file_rename: общий guard на nil/"" ---
    if type(prompts.get_file_rename) == "function" then
        local orig = prompts.get_file_rename
        prompts.get_file_rename = function(original_path, callback)
            orig(original_path, function(input)
                if input == nil or input == "" then return end
                callback(input)
            end)
        end
    end

    -- --- (2) should_delete: безопасная альтернатива upstream ---
    prompts.should_delete = function(path, callback)
        vim.ui.input({
            prompt = string.format("delete %s? (Y/n): ", vim.fn.fnamemodify(path, ":t")),
        }, function(input)
            if not input then return end           -- <Esc> или закрытие
            if input:lower() ~= "y" then return end -- "n", "no", "" и т.п.
            callback()
        end)
    end

    prompts.__forge_patched = true
end

local function patch_bufferlist()
    -- Upstream leaks `print(vim.inspect(keymap))` inside BufferList's
    -- buffer-setup loop, spamming :messages every time it renders.
    -- Wrap the constructor so `setup_buffer` (called from open()) runs
    -- with `print` silenced. Must run BEFORE the bufferlist init module
    -- requires the component, since init caches `new` into the factory.
    local ok, bl = pcall(require, "ide.components.bufferlist.component")
    if not ok or bl.__forge_patched then return end
    local original_new = bl.new
    bl.new = function(name, cfg)
        local self = original_new(name, cfg)
        if self and type(self.open) == "function" then
            local original_open = self.open
            self.open = function(...)
                local saved = _G.print
                _G.print = function() end
                local ok_open, result = pcall(original_open, ...)
                _G.print = saved
                if not ok_open then error(result) end
                return result
            end
        end
        return self
    end
    bl.__forge_patched = true
end

-- All component names within each panel group, in stack order.
local EXPLORER_GROUP = {
    "Explorer", "Outline", "BufferList", "Bookmarks", "CallHierarchy",
    "TerminalBrowser",
}
local GIT_GROUP = { "Changes", "Commits", "Branches", "Timeline" }

local function group_for(component)
    for _, name in ipairs(EXPLORER_GROUP) do
        if name == component then return "explorer", "left", EXPLORER_GROUP end
    end
    for _, name in ipairs(GIT_GROUP) do
        if name == component then return "git", "right", GIT_GROUP end
    end
end

local function find_component(name)
    local ok, registry = pcall(require, "ide.workspaces.workspace_registry")
    if not ok or not registry.get_workspace then return end
    local ws = registry.get_workspace(vim.api.nvim_get_current_tabpage())
    if not ws or not ws.panels then return end
    for _, panel in pairs(ws.panels) do
        if panel and panel.components then
            for _, c in ipairs(panel.components) do
                if c.name == name then return c, panel, ws end
            end
        end
    end
end

-- Public helper: reveal only `component_name` inside its panel group.
-- Hides every sibling. Opens the panel if it's closed. Focuses target.
local function show(component_name)
    local _, position, siblings = group_for(component_name)
    if not position then return end

    local _, _, ws = find_component(component_name)
    if not ws then return end

    for _, sibling in ipairs(siblings) do
        local c = find_component(sibling)
        if c then
            if sibling == component_name then
                c.hidden = false
            else
                if c.is_displayed and c.is_displayed() then
                    pcall(c.hide, c)
                else
                    c.hidden = true
                end
            end
        end
    end

    local panel_consts = require("ide.panels.panel")
    local const = position == "left" and panel_consts.PANEL_POS_LEFT
        or panel_consts.PANEL_POS_RIGHT
    pcall(ws.open_panel, ws, const)

    vim.schedule(function()
        local target = find_component(component_name)
        if target and type(target.focus) == "function" then
            pcall(target.focus, target)
        end
    end)
end

return {
    {
        "ldelossa/nvim-ide",
        lazy = false,
        priority = 800,
        keys = {
            -- Panel toggles
            { "<C-e>",      "<cmd>Workspace LeftPanelToggle<CR>",  desc = "IDE: toggle left panel" },
            { "<C-S-e>",    "<cmd>Workspace RightPanelToggle<CR>", desc = "IDE: toggle right panel" },
            { "<leader>e",  function() show("Explorer") end,       desc = "IDE: Explorer" },
            { "<leader>E",  "<cmd>Workspace LeftPanelToggle<CR>",  desc = "IDE: toggle left" },

            -- Component switches inside the left panel (explorer group)
            { "<leader>tf", function() show("Explorer") end,       desc = "Left: Files" },
            { "<leader>to", function() show("Outline") end,        desc = "Left: Outline" },
            { "<leader>tb", function() show("BufferList") end,     desc = "Left: BufferList" },
            { "<leader>tm", function() show("Bookmarks") end,      desc = "Left: Bookmarks" },
            { "<leader>tc", function() show("CallHierarchy") end,  desc = "Left: CallHierarchy" },

            -- Component switches inside the right panel (git group)
            { "<leader>gs", function() show("Changes") end,        desc = "Right: Git Changes" },
            { "<leader>gl", function() show("Commits") end,        desc = "Right: Git Commits (log)" },
            { "<leader>gB", function() show("Branches") end,       desc = "Right: Git Branches" },
            { "<leader>gt", function() show("Timeline") end,       desc = "Right: Git Timeline" },

            -- Panel-group swap dialog (built-in nvim-ide command)
            { "<leader>ts", "<cmd>Workspace SwapPanel<CR>",        desc = "IDE: swap panel group" },
        },
        config = function()
            -- Patch upstream bugs in-memory before setup().
            patch_workspace_registry()
            patch_bufferlist()
            patch_explorer_prompts()

            -- Each Init module registers a component constructor; we must
            -- require them so they appear in the component factory.
            local explorer        = require("ide.components.explorer")
            local outline         = require("ide.components.outline")
            local bufferlist      = require("ide.components.bufferlist")
            local bookmarks       = require("ide.components.bookmarks")
            local callhierarchy   = require("ide.components.callhierarchy")
            local terminal        = require("ide.components.terminal")
            local terminalbrowser = require("ide.components.terminal.terminalbrowser")
            local changes         = require("ide.components.changes")
            local commits         = require("ide.components.commits")
            local branches        = require("ide.components.branches")
            local timeline        = require("ide.components.timeline")

            local explorer_keys = require("ide.components.explorer.presets")

            require("ide").setup({
                icon_set  = vim.g.have_nerd_font and "nerd" or "default",
                log_level = "info",
                components = {
                    global_keymaps = {
                        -- Default `H` (hide) collides with our buffer-prev
                        -- mapping `<S-h>`. Move hide to `q`.
                        hide = "q",
                    },
                    Explorer = { keymaps = explorer_keys.default },

                    -- VSCode-style: start with only one section visible
                    -- per panel; the rest are revealed on demand by show().
                    Outline         = { hidden = true },
                    BufferList      = { hidden = true },
                    TerminalBrowser = { hidden = true },
                    Commits         = { hidden = true },
                    Branches        = { hidden = true },
                    Timeline        = { hidden = true },
                },
                panels = {
                    left   = "explorer",
                    right  = "git",
                    bottom = "terminal",
                },
                panel_groups = {
                    explorer = {
                        explorer.Name,
                        outline.Name,
                        bufferlist.Name,
                        bookmarks.Name,
                        callhierarchy.Name,
                        terminalbrowser.Name,
                    },
                    git = {
                        changes.Name,
                        commits.Name,
                        branches.Name,
                        timeline.Name,
                    },
                    terminal = { terminal.Name },
                },
                workspaces = {
                    auto_open = "left",
                    on_quit   = "close",
                },
                panel_sizes = {
                    left   = 32,
                    right  = 36,
                    bottom = 15,
                },
            })

            -- Expose show() globally so `<cmd>` mappings, autocmds and
            -- which-key descriptions can call it without an import.
            _G.IDEShow = show

            -- Дополнительные buffer-local маппинги для Explorer-буфера.
            -- nvim-ide preset допускает только одну клавишу на действие
            -- (`edit = "<CR>"`), поэтому второй ключ (`l` = войти/открыть)
            -- навешиваем через FileType-хук на буфер с ft=filetree.
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "filetree",
                desc = "IDE Explorer: l → open file / expand dir (как <CR>)",
                callback = function(args)
                    vim.schedule(function()
                        local c = find_component("Explorer")
                        if not c or type(c.open_filenode) ~= "function" then return end
                        vim.keymap.set("n", "l", function()
                            c.open_filenode({ fargs = {} })
                        end, {
                            buffer = args.buf,
                            silent = true,
                            desc = "Explorer: open file / expand dir",
                        })
                    end)
                end,
            })
        end,
    },
}
