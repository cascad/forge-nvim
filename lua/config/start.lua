local M = {}

local recent_cache = {}
local open_files_layout
local close_file_buffers

local function normalize_dir(path)
    path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    if path:match("^%a:/$") then
        return path
    end
    return (path:gsub("[/\\]+$", ""))
end

local function normalized_key(path)
    local key = normalize_dir(path):gsub("\\", "/")
    if vim.fn.has("win32") == 1 then
        key = key:lower()
    end
    return key
end

local function path_inside_dir(path, dir)
    local file = normalized_key(path)
    local root = normalized_key(dir)
    return file == root or file:sub(1, #root + 1) == root .. "/"
end

local function normal_file_buffers(match)
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" and (not match or match(name, buf)) then
                buffers[#buffers + 1] = buf
            end
        end
    end
    return buffers
end

local function modified_normal_buffers()
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and vim.bo[buf].modified then
            buffers[#buffers + 1] = buf
        end
    end
    return buffers
end

local function visible_normal_file_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
                return win
            end
        end
    end
end

local function first_listed_file_buffer()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= "" and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
            return buf
        end
    end
end

local function readable_dir(path)
    return path and path ~= "" and vim.fn.isdirectory(path) == 1
end

local function recent_projects(limit)
    local ok, project_nvim = pcall(require, "project_nvim")
    if not ok or type(project_nvim.get_recent_projects) ~= "function" then
        return {}
    end

    local projects = project_nvim.get_recent_projects() or {}
    local result = {}
    for index = #projects, 1, -1 do
        local path = projects[index]
        if readable_dir(path) then
            result[#result + 1] = normalize_dir(path)
            if limit and #result >= limit then break end
        end
    end
    return result
end

local function close_start_buffer()
    if vim.bo.filetype == "alpha" then
        vim.cmd("enew")
    end
end

local function write_modified_buffers()
    if #modified_normal_buffers() == 0 then
        return true
    end

    local ok, err = pcall(vim.cmd, "silent wall")
    if not ok then
        vim.notify("Could not write modified buffers: " .. tostring(err), vim.log.levels.ERROR, { title = "Start" })
        return false
    end

    if #modified_normal_buffers() > 0 then
        vim.notify("Project switch aborted: save modified buffers first", vim.log.levels.WARN, { title = "Start" })
        return false
    end
    return true
end

local function save_current_session(root)
    root = normalize_dir(root or vim.fn.getcwd())
    if #normal_file_buffers(function(name) return path_inside_dir(name, root) end) == 0 then
        return true
    end

    if not close_file_buffers(function(name) return not path_inside_dir(name, root) end) then
        vim.notify("Project switch aborted: could not close non-project buffers", vim.log.levels.ERROR, { title = "Start" })
        return false
    end

    local ok_panels, panels = pcall(require, "config.panels")
    if ok_panels and type(panels.prepare_session_save) == "function" then
        panels.prepare_session_save()
    end

    local ok, persistence = pcall(require, "persistence")
    if ok and type(persistence.save) == "function" then
        pcall(persistence.save)
    end
    return true
end

close_file_buffers = function(match)
    local buffers = normal_file_buffers(match)
    if #buffers == 0 then
        return true
    end

    local targets = {}
    for _, buf in ipairs(buffers) do
        targets[buf] = true
    end

    local scratch
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
            if ok_buf and targets[buf] then
                scratch = scratch or vim.api.nvim_create_buf(false, true)
                pcall(vim.api.nvim_win_set_buf, win, scratch)
            end
        end
    end

    local failed = {}
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
            if not ok then
                failed[#failed + 1] = tostring(err)
            end
        end
    end

    if #failed > 0 then
        vim.notify(table.concat(failed, "\n"), vim.log.levels.ERROR, { title = "Start: close buffers" })
        return false
    end
    return true
end

local function cleanup_restored_session()
    local ok_panels, panels = pcall(require, "config.panels")
    if ok_panels and type(panels.prepare_session_save) == "function" then
        panels.prepare_session_save()
    end

    local win = visible_normal_file_window()
    if win then
        vim.api.nvim_set_current_win(win)
        return
    end

    local buf = first_listed_file_buffer()
    if buf then
        pcall(vim.cmd, "buffer " .. buf)
    elseif open_files_layout then
        open_files_layout()
    end
end

local function load_session_if_present()
    local ok, persistence = pcall(require, "persistence")
    if not ok then return false end

    local session = persistence.current()
    if vim.fn.filereadable(session) == 0 then
        session = persistence.current({ branch = false })
    end
    if vim.fn.filereadable(session) == 0 then
        return false
    end

    persistence.load()
    vim.schedule(cleanup_restored_session)
    return true
end

open_files_layout = function()
    close_start_buffer()
    local ok, panels = pcall(require, "config.panels")
    if ok then
        panels.mode_files()
    else
        vim.cmd("edit .")
    end
end

local function open_code_only_layout()
    close_start_buffer()
    if not visible_normal_file_window() then
        vim.cmd("enew")
    end
end

local function set_project_dir(path)
    local ok_project, project = pcall(require, "project_nvim.project")
    if ok_project and type(project.set_pwd) == "function" then
        project.set_pwd(path, "start")
    else
        vim.api.nvim_set_current_dir(path)
    end
end

function M.open_project_after_restart(path, open_files)
    path = path and normalize_dir(path)
    if not readable_dir(path) then
        vim.notify("Project path is not a directory: " .. tostring(path), vim.log.levels.ERROR, { title = "Start" })
        return
    end

    set_project_dir(path)

    if not load_session_if_present() then
        if open_files then
            open_files_layout()
        else
            open_code_only_layout()
        end
    end
end

local function restart_project(path, opts)
    if vim.fn.exists(":restart") ~= 2 then
        vim.notify("Project switch requires Neovim :restart; aborting.", vim.log.levels.ERROR, { title = "Start" })
        return
    end

    local current_path = normalize_dir(vim.fn.getcwd())
    if current_path == path then
        return
    end

    if not write_modified_buffers() then
        return
    end

    local ok_panels, panels = pcall(require, "config.panels")
    if ok_panels and type(panels.stop_debug) == "function" then
        pcall(panels.stop_debug)
    end

    if not save_current_session(current_path) then
        return
    end

    local open_files = opts.open_files ~= false
    local command = ("restart +qall! lua require('config.start').open_project_after_restart(%s, %s)")
        :format(string.format("%q", path), open_files and "true" or "false")
    local ok, err = pcall(vim.cmd, command)
    if not ok then
        vim.notify("Hard project switch failed: " .. tostring(err), vim.log.levels.ERROR, { title = "Start" })
    end
end

function M.open_project(path, opts)
    opts = opts or {}
    path = path and normalize_dir(path)
    if not readable_dir(path) then
        vim.notify("Project path is not a directory: " .. tostring(path), vim.log.levels.ERROR, { title = "Start" })
        return
    end

    local current_path = normalize_dir(vim.fn.getcwd())
    if current_path ~= path then
        restart_project(path, opts)
        return
    end

    if #normal_file_buffers() > 0 then
        close_start_buffer()
        return
    end

    if not load_session_if_present() then
        if opts.open_files ~= false then
            open_files_layout()
        else
            open_code_only_layout()
        end
    end
end

function M.open_recent(index)
    M.open_project(recent_cache[index])
end

function M.work_in_current_folder()
    open_code_only_layout()
end

function M.open_home()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "alpha" then
                vim.api.nvim_set_current_win(win)
                return
            end
        end
    end

    vim.cmd("Alpha")
end

local function editable_project_path(path)
    path = normalize_dir(path or vim.fn.getcwd())
    if path:match("^%a:/$") or path == "/" then
        return path
    end
    return path .. "/"
end

function M.open_path_prompt(default_path)
    local path = vim.fn.input("Open project path: ", editable_project_path(default_path), "dir")
    if path and path ~= "" then
        M.open_project(path, { open_files = false })
    end
end

function M.open_folder_picker(path)
    M.open_path_prompt(path)
end

local function select_project_with_vim_ui(projects)
    vim.ui.select(projects, {
        prompt = "Recent projects",
        format_item = function(path)
            return vim.fn.fnamemodify(path, ":p:~")
        end,
    }, function(path)
        if path then
            M.open_project(path)
        end
    end)
end

function M.open_projects_picker()
    local projects = recent_projects()
    if #projects == 0 then
        vim.notify("No recent projects yet", vim.log.levels.INFO, { title = "Start" })
        return
    end

    local ok, pickers = pcall(require, "telescope.pickers")
    if not ok then
        select_project_with_vim_ui(projects)
        return
    end

    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local state = require("telescope.actions.state")
    local entry_display = require("telescope.pickers.entry_display")
    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 30 },
            { remaining = true },
        },
    })

    pickers.new({}, {
        prompt_title = "Recent Projects",
        previewer = false,
        finder = finders.new_table({
            results = projects,
            entry_maker = function(path)
                local name = vim.fn.fnamemodify(path, ":t")
                local display_path = vim.fn.fnamemodify(path, ":p:~")
                return {
                    value = path,
                    ordinal = name .. " " .. display_path,
                    display = function(entry)
                        return displayer({ entry.name, { entry.path, "Comment" } })
                    end,
                    name = name,
                    path = display_path,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local entry = state.get_selected_entry()
                actions.close(prompt_bufnr)
                if entry then
                    M.open_project(entry.value)
                end
            end)
            return true
        end,
    }):find()
end

function M.buttons(dashboard)
    local buttons = {
        dashboard.button("p", "  Recent projects picker", "<cmd>lua require('config.start').open_projects_picker()<CR>"),
        dashboard.button("w", "  Work in current folder", "<cmd>lua require('config.start').work_in_current_folder()<CR>"),
        dashboard.button("f", "  Find file in current cwd", "<cmd>Telescope find_files<CR>"),
        dashboard.button("r", "  Restore session for cwd", "<cmd>lua require('persistence').load()<CR>"),
        dashboard.button("o", "  Open folder path", "<cmd>lua require('config.start').open_path_prompt()<CR>"),
    }

    recent_cache = recent_projects(8)
    for index, path in ipairs(recent_cache) do
        local name = vim.fn.fnamemodify(path, ":t")
        local display = vim.fn.fnamemodify(path, ":p:~")
        buttons[#buttons + 1] = dashboard.button(
            tostring(index),
            ("  %s  %s"):format(name, display),
            ("<cmd>lua require('config.start').open_recent(%d)<CR>"):format(index)
        )
    end

    buttons[#buttons + 1] = dashboard.button("q", "  Quit", "<cmd>qa<CR>")
    return buttons
end

function M.footer()
    local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:~")
    return "cwd: " .. cwd
end

return M
