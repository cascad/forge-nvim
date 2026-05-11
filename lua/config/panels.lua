-- IDE mode/layout controller.
--
-- The rule is intentionally simple: one mode owns the side/bottom tool
-- windows at a time. Switching mode closes unrelated tool windows and opens a
-- coherent layout, closer to an IDE activity bar than to a shared accordion.

local M = {}

M.current_mode = "code"

local explorer_modes = {
    files = true,
    buffers = true,
    git = true,
}

local tool_filetypes = {
    ["neo-tree"] = true,
    ["dap-repl"] = true,
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["dap-view-help"] = true,
    ["neotest-summary"] = true,
    ["neotest-output-panel"] = true,
    ["OverseerList"] = true,
    ["overseer"] = true,
    ["overseer-list"] = true,
    ["grug-far"] = true,
    ["qf"] = true,
}

local session_unsafe_filetypes = vim.tbl_extend("force", tool_filetypes, {
    ["alpha"] = true,
    ["lazy"] = true,
    ["mason"] = true,
    ["TelescopePrompt"] = true,
    ["TelescopeResults"] = true,
})

local session_unsafe_buftypes = {
    ["nofile"] = true,
    ["prompt"] = true,
    ["quickfix"] = true,
    ["terminal"] = true,
}

local function pcall_cmd(cmd)
    pcall(vim.cmd, cmd)
end

local function dapview_cmd(cmd)
    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
        vim.notify(cmd .. " failed: " .. tostring(err), vim.log.levels.ERROR, { title = "DAP View" })
        return false
    end
    return true
end

local function load_lazy(plugin)
    local ok, lazy = pcall(require, "lazy")
    if ok then pcall(lazy.load, { plugins = { plugin } }) end
end

local function get_neotest()
    local ok, neotest = pcall(require, "neotest")
    if not ok then
        load_lazy("neotest")
        ok, neotest = pcall(require, "neotest")
    end
    return ok and neotest or nil
end

local function get_overseer()
    local ok, overseer = pcall(require, "overseer")
    if not ok then
        load_lazy("overseer.nvim")
        ok, overseer = pcall(require, "overseer")
    end
    return ok and overseer or nil
end

local function close_windows(match)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if match(buf, win) then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end
end

local function close_filetypes(filetypes)
    close_windows(function(buf)
        return filetypes[vim.bo[buf].filetype] == true
    end)
end

local function find_window(ft, predicate)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local matches_ft = not ft or vim.bo[buf].filetype == ft
            local matches_predicate = not predicate or predicate(buf, win)
            if matches_ft and matches_predicate then
                return win
            end
        end
    end
end

local function is_visible(ft, predicate)
    return find_window(ft, predicate) ~= nil
end

local function has_buffer_filetype(ft)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == ft then
            return true
        end
    end
    return false
end

local function focus_window(ft, predicate)
    local win = find_window(ft, predicate)
    if win then
        vim.api.nvim_set_current_win(win)
        return true
    end
    return false
end

local function is_code_window(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    local bt = vim.bo[buf].buftype
    return not tool_filetypes[ft] and bt ~= "nofile" and bt ~= "prompt"
end

local function find_code_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_code_window(win) then
            return win
        end
    end
end

local function focus_code_window()
    local win = find_code_window()
    if win then
        vim.api.nvim_set_current_win(win)
        return true
    end
    return false
end

local function neo_tree_source(source)
    return function(buf)
        return vim.b[buf].neo_tree_source == source
    end
end

local function focus_later(ft, predicate)
    vim.schedule(function()
        if focus_window(ft, predicate) then return end
        vim.defer_fn(function()
            focus_window(ft, predicate)
        end, 50)
    end)
end

local function focus_code_later()
    vim.schedule(function()
        if focus_code_window() then return end
        vim.defer_fn(focus_code_window, 50)
    end)
end

local debug_filetypes = {
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["dap-view-help"] = true,
    ["dap-repl"] = true,
}

local function any_filetype_visible(filetypes)
    return find_window(nil, function(buf)
        return filetypes[vim.bo[buf].filetype] == true
    end) ~= nil
end

local function is_debug_buffer(buf)
    return debug_filetypes[vim.bo[buf].filetype] == true
end

local function is_jobs_buffer(buf)
    local ft = vim.bo[buf].filetype:lower()
    local name = vim.api.nvim_buf_get_name(buf):lower()
    return ft:find("overseer", 1, true) ~= nil
        or name:find("overseer", 1, true) ~= nil
end

function M.close_files()
    if package.loaded["neo-tree"] or has_buffer_filetype("neo-tree") then
        pcall_cmd("Neotree close")
    end
    close_filetypes({ ["neo-tree"] = true })
end

function M.close_debug()
    pcall(vim.cmd, "DapViewClose!")
    close_filetypes(debug_filetypes)
end

function M.close_tests()
    local neotest = package.loaded["neotest"]
    if neotest then
        pcall(neotest.summary.close)
        pcall(neotest.output_panel.close)
    end
    close_filetypes({
        ["neotest-summary"] = true,
        ["neotest-output-panel"] = true,
    })
end

function M.close_jobs()
    local overseer = package.loaded["overseer"]
    if overseer then pcall(overseer.close) end
    pcall_cmd("OverseerClose")
end

function M.close_search()
    pcall_cmd("GrugFarClose")
    close_filetypes({ ["grug-far"] = true })
end

function M.close_quickfix()
    pcall_cmd("cclose")
end

function M.stop_debug()
    local dap = package.loaded["dap"]
    if not dap or not dap.session or not dap.session() then
        return false
    end

    -- Prefer DAP terminate. If an adapter ignores it, disconnect with
    -- terminateDebuggee is the stronger fallback.
    local ok = pcall(function()
        dap.terminate({ terminateDebuggee = true })
    end)
    if not ok then
        pcall(function()
            dap.disconnect({ terminateDebuggee = true })
        end)
    end

    return true
end

function M.close_activity(except)
    if not explorer_modes[except] then M.close_files() end
    if except ~= "debug" then M.close_debug() end
    if except ~= "tests" then M.close_tests() end
    if except ~= "jobs" then M.close_jobs() end
    if except ~= "search" then M.close_search() end
    if except ~= "quickfix" then M.close_quickfix() end
end

function M.prepare_session_save()
    M.close_activity(nil)

    close_windows(function(buf)
        return session_unsafe_filetypes[vim.bo[buf].filetype] == true
            or session_unsafe_buftypes[vim.bo[buf].buftype] == true
    end)

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            local ft = vim.bo[buf].filetype
            local bt = vim.bo[buf].buftype
            local name = vim.api.nvim_buf_get_name(buf)
            if session_unsafe_filetypes[ft] or session_unsafe_buftypes[bt] or name:find("neo%-tree", 1, false) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
end

function M.mode_files()
    M.close_activity("files")
    M.current_mode = "files"
    pcall_cmd("Neotree filesystem reveal left")
    focus_later("neo-tree", neo_tree_source("filesystem"))
end

function M.mode_buffers()
    M.close_activity("buffers")
    M.current_mode = "buffers"
    pcall_cmd("Neotree buffers reveal left")
    focus_later("neo-tree", neo_tree_source("buffers"))
end

function M.mode_git()
    M.close_activity("git")
    M.current_mode = "git"
    pcall_cmd("Neotree git_status reveal left")
    focus_later("neo-tree", neo_tree_source("git_status"))
end

function M.show_debug_section(section, enter)
    M.close_activity("debug")
    M.current_mode = "debug"

    if not dapview_cmd("DapViewOpen") then
        focus_code_later()
        return
    end
    if section then
        dapview_cmd("DapViewShow " .. section)
    end

    if enter then
        focus_later(nil, is_debug_buffer)
    else
        focus_code_later()
    end
end

function M.mode_debug()
    -- По умолчанию Console (PTY дебагги-процесса для Rust/Python через
    -- runInTerminal). Для go/delve - REPL, потому что delve в mode=debug
    -- не уважает console=integratedTerminal и шлёт stdout через DAP
    -- output events в REPL (см. PANELS.md "Output: console vs REPL"
    -- + DEBUG_SETUP_JOURNEY эпизод 6.9). Если сессия активна - берём
    -- секцию по её типу, чтобы повторные <leader>md не сбивали фокус.
    local section = "console"
    local ok, dap = pcall(require, "dap")
    if ok then
        local session = dap.session()
        local type_ = session and session.config and session.config.type
        if type_ == "go" or type_ == "delve" then
            section = "repl"
        end
    end
    M.show_debug_section(section, false)
end

function M.mode_tests()
    M.close_activity("tests")
    M.current_mode = "tests"

    local neotest = get_neotest()
    if neotest then
        pcall(neotest.summary.open)
        pcall(neotest.output_panel.open)
    end

    focus_later("neotest-summary", nil)
end

function M.mode_search()
    M.close_activity("search")
    M.current_mode = "search"
    pcall_cmd("botright vertical GrugFar")
    focus_later("grug-far", nil)
end

function M.mode_output()
    M.current_mode = "debug-output"
    M.show_debug_section("console", true)
    M.current_mode = "debug-output"
end

function M.mode_jobs()
    M.close_activity("jobs")
    M.current_mode = "jobs"

    local overseer = get_overseer()
    if overseer then
        pcall(overseer.open, { direction = "bottom", enter = true })
    else
        pcall_cmd("OverseerOpen bottom")
    end

    focus_later(nil, is_jobs_buffer)
end

function M.mode_code()
    M.close_activity(nil)
    M.current_mode = "code"
    focus_code_window()
end

function M.close_ide()
    local had_debug_session = M.stop_debug()

    M.close_activity(nil)
    M.current_mode = "code"
    focus_code_window()

    -- DAP may emit late events while terminating. Close once more after those
    -- callbacks settle so the UI does not reappear after :IdeClose.
    if had_debug_session then
        vim.defer_fn(function()
            M.close_debug()
            focus_code_window()
        end, 120)
    end
end

function M.select_mode()
    local choices = {
        { label = "Files", action = M.mode_files },
        { label = "Buffers", action = M.mode_buffers },
        { label = "Git", action = M.mode_git },
        { label = "Debug", action = M.mode_debug },
        { label = "Tests", action = M.mode_tests },
        { label = "Jobs", action = M.mode_jobs },
        { label = "Search", action = M.mode_search },
        { label = "Output", action = M.mode_output },
        { label = "Code only", action = M.mode_code },
        { label = "Close IDE", action = M.close_ide },
    }

    vim.ui.select(choices, {
        prompt = "IDE mode:",
        format_item = function(item) return item.label end,
    }, function(choice)
        if choice then choice.action() end
    end)
end

function M.toggle_files()
    if is_visible("neo-tree", neo_tree_source("filesystem")) then
        M.close_files()
        focus_code_window()
    else
        M.mode_files()
    end
end

function M.open_files()
    M.mode_files()
end

function M.toggle_git_status()
    if is_visible("neo-tree", neo_tree_source("git_status")) then
        M.close_files()
        focus_code_window()
    else
        M.mode_git()
    end
end

function M.open_git_status()
    M.mode_git()
end

function M.toggle_debug()
    if any_filetype_visible(debug_filetypes) then
        M.close_debug()
        focus_code_window()
    else
        M.mode_debug()
    end
end

function M.open_debug()
    M.mode_debug()
end

function M.toggle_tests()
    if is_visible("neotest-summary", nil) or is_visible("neotest-output-panel", nil) then
        M.close_tests()
        focus_code_window()
    else
        M.mode_tests()
    end
end

function M.open_tests()
    M.mode_tests()
end

function M.toggle_test_output()
    local neotest = get_neotest()
    if neotest then neotest.output_panel.toggle() end
end

function M.open_search()
    M.mode_search()
end

-- Backward-compatible focus helpers. They now switch to the owning mode first,
-- then focus the requested window inside that mode.
function M.focus_files()
    M.mode_files()
end

function M.focus_buffers()
    M.mode_buffers()
end

function M.focus_git()
    M.mode_git()
end

function M.focus_tests()
    M.mode_tests()
end

function M.focus_debug_scopes()
    M.show_debug_section("scopes", true)
end

function M.focus_debug_breakpoints()
    M.show_debug_section("breakpoints", true)
end

function M.focus_debug_stacks()
    M.show_debug_section("threads", true)
end

function M.focus_debug_watches()
    M.show_debug_section("watches", true)
end

function M.focus_dap_console()
    M.mode_output()
end

function M.focus_dap_repl()
    M.open_dap_repl()
end

function M.open_dap_repl()
    M.show_debug_section("repl", true)
end

function M.focus_test_output()
    M.mode_tests()
    focus_later("neotest-output-panel", nil)
end

function M.focus_search()
    M.mode_search()
end

function M.focus_quickfix()
    M.close_activity("quickfix")
    M.current_mode = "quickfix"
    pcall_cmd("copen")
    focus_later("qf", nil)
end

local function mode_entries()
    local code = { label = "Code", code = true }
    local mode = M.current_mode

    if mode == "files" then
        return {
            code,
            {
                label = "Files",
                ft = "neo-tree",
                predicate = neo_tree_source("filesystem"),
                open = M.mode_files,
            },
        }
    end

    if mode == "buffers" then
        return {
            code,
            {
                label = "Buffers",
                ft = "neo-tree",
                predicate = neo_tree_source("buffers"),
                open = M.mode_buffers,
            },
        }
    end

    if mode == "git" then
        return {
            code,
            {
                label = "Git",
                ft = "neo-tree",
                predicate = neo_tree_source("git_status"),
                open = M.mode_git,
            },
        }
    end

    if mode == "debug" then
        return {
            code,
            { label = "Console",     predicate = is_debug_buffer, show_debug = "console",     open = function() M.show_debug_section("console", true) end },
            { label = "Scopes",      predicate = is_debug_buffer, show_debug = "scopes",      open = function() M.show_debug_section("scopes", true) end },
            { label = "Breakpoints", predicate = is_debug_buffer, show_debug = "breakpoints", open = function() M.show_debug_section("breakpoints", true) end },
            { label = "Threads",     predicate = is_debug_buffer, show_debug = "threads",     open = function() M.show_debug_section("threads", true) end },
            { label = "Watches",     predicate = is_debug_buffer, show_debug = "watches",     open = function() M.show_debug_section("watches", true) end },
            { label = "REPL",        predicate = is_debug_buffer, show_debug = "repl",        open = function() M.show_debug_section("repl", true) end },
        }
    end

    if mode == "debug-output" then
        return {
            code,
            { label = "Console", predicate = is_debug_buffer, show_debug = "console", open = M.mode_output },
        }
    end

    if mode == "tests" then
        return {
            code,
            { label = "Test Summary", ft = "neotest-summary",       open = M.mode_tests },
            { label = "Test Output",  ft = "neotest-output-panel",  open = M.mode_tests },
        }
    end

    if mode == "jobs" then
        return {
            code,
            { label = "Jobs", predicate = is_jobs_buffer, open = M.mode_jobs },
        }
    end

    if mode == "search" then
        return {
            code,
            { label = "Search", ft = "grug-far", open = M.mode_search },
        }
    end

    if mode == "quickfix" then
        return {
            code,
            { label = "Quickfix", ft = "qf", open = M.focus_quickfix },
        }
    end

    return { code }
end

local function mode_tool_entries()
    local tools = {}
    for _, entry in ipairs(mode_entries()) do
        if not entry.code then
            table.insert(tools, entry)
        end
    end
    return tools
end

local function entry_window(entry)
    if entry.code then return find_code_window() end
    return find_window(entry.ft, entry.predicate)
end

local function focus_entry(entry)
    if entry.show_debug then
        pcall_cmd("DapViewShow " .. entry.show_debug)
    end

    local win = entry_window(entry)
    if win then
        vim.api.nvim_set_current_win(win)
        return true
    end
    return false
end

local function visible_mode_entries()
    local visible = {}
    for _, entry in ipairs(mode_entries()) do
        local win = entry_window(entry)
        if win then
            table.insert(visible, { entry = entry, win = win })
        end
    end
    return visible
end

local function focus_mode_entry_later(entry)
    vim.schedule(function()
        if focus_entry(entry) then return end
        vim.defer_fn(function()
            focus_entry(entry)
        end, 80)
    end)
end

function M.focus_code()
    focus_code_window()
end

function M.focus_mode_slot(slot)
    local entry = mode_tool_entries()[slot]
    if not entry then
        vim.notify("No slot " .. slot .. " in current mode", vim.log.levels.INFO)
        return
    end

    if focus_entry(entry) then return end
    if entry.open then
        entry.open()
        focus_mode_entry_later(entry)
    end
end

function M.next_mode_window()
    if M.current_mode == "debug" or M.current_mode == "debug-output" then
        local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
        if is_debug_buffer(buf) then
            pcall_cmd("DapViewNavigate! 1")
            return
        end
    end

    local visible = visible_mode_entries()
    if #visible == 0 then return end

    local current = vim.api.nvim_get_current_win()
    local current_index = 0
    for index, item in ipairs(visible) do
        if item.win == current then
            current_index = index
            break
        end
    end

    local next_index = current_index % #visible + 1
    vim.api.nvim_set_current_win(visible[next_index].win)
end

function M.prev_mode_window()
    if M.current_mode == "debug" or M.current_mode == "debug-output" then
        local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
        if is_debug_buffer(buf) then
            pcall_cmd("DapViewNavigate! -1")
            return
        end
    end

    local visible = visible_mode_entries()
    if #visible == 0 then return end

    local current = vim.api.nvim_get_current_win()
    local current_index = 1
    for index, item in ipairs(visible) do
        if item.win == current then
            current_index = index
            break
        end
    end

    local prev_index = current_index - 1
    if prev_index < 1 then prev_index = #visible end
    vim.api.nvim_set_current_win(visible[prev_index].win)
end

if not vim.g.user_ide_panel_commands_registered then
    vim.g.user_ide_panel_commands_registered = true

    vim.api.nvim_create_user_command("IdeClose", function()
        require("config.panels").close_ide()
    end, {
        desc = "Close IDE tool windows and terminate an active debug session",
    })

    vim.api.nvim_create_user_command("IdeMode", function()
        require("config.panels").select_mode()
    end, {
        desc = "Select IDE mode",
    })
end

return M
