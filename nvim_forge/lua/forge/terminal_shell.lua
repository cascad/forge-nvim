-- spec: IDE-PANEL-19 IDE-PANEL-33. Shell preference for managed consoles.
local M = {}
local paths = require('forge.tool_paths')
local windows = vim.fn.has('win32') == 1
local setting = 'terminal-shell'
local last_warning

local function auto()
    if windows and vim.fn.executable('pwsh') == 1 then return 'pwsh -NoLogo' end
    return vim.o.shell
end

local function executable(path)
    local stat = vim.uv.fs_stat(path)
    if stat and stat.type == 'file' and vim.fn.executable(path) == 1 then return path end
end

local function preference()
    return pcall(paths.override, setting, { scope = 'user', validate = executable })
end

local function shell_command(path)
    local name = vim.fs.basename(path):lower():gsub('%.exe$', '')
    local command = vim.fn.shellescape(path)
    if windows and vim.o.shell:lower():find('cmd', 1, true) then
        -- cmd /c treats quotes at the start of its command specially.
        command = '@' .. vim.fn.shellescape(path:gsub('/', '\\'))
    end
    if name == 'pwsh' or name == 'powershell' then command = command .. ' -NoLogo' end
    return command
end

function M.command()
    local ok, path = preference()
    if ok then
        last_warning = nil
        return path and shell_command(path) or auto()
    end
    if path ~= last_warning then
        last_warning = path
        vim.schedule(function()
            vim.notify(path .. '\nВыбран Auto. Настройка оболочки доступна в :ForgeTerminalShell.',
                vim.log.levels.WARN, { title = 'Терминал' })
        end)
    end
    return auto()
end

local function choices()
    local options = { { label = 'Auto — ' .. auto() }, { label = 'Указать путь к бинарю…', custom = true } }
    local seen = {}
    local function add(path)
        if path == '' then return end
        path = vim.fs.normalize(path)
        local key = windows and path:lower() or path
        if seen[key] or not executable(path) then return end
        seen[key] = true
        options[#options + 1] = { label = vim.fs.basename(path) .. ' — ' .. path, path = path }
    end
    local names = windows and { 'pwsh', 'powershell', 'cmd', 'bash', 'zsh', 'fish', 'nu' }
        or { 'bash', 'zsh', 'fish', 'sh', 'ksh', 'tcsh', 'dash', 'nu', 'pwsh' }
    for _, name in ipairs(names) do add(vim.fn.exepath(name)) end
    if not windows and vim.fn.filereadable('/etc/shells') == 1 then
        for _, line in ipairs(vim.fn.readfile('/etc/shells', '', 128)) do
            local path = vim.trim(line)
            if path:sub(1, 1) == '/' then add(path) end
        end
    end
    return options
end

local function save(path)
    local ok, error_message = pcall(paths.save, setting, path, 'user')
    if not ok then
        vim.notify(tostring(error_message), vim.log.levels.ERROR, { title = 'Терминал' })
        return
    end
    vim.notify('Оболочка новых консолей — ' .. (path or 'Auto') .. '. Новая консоль: Space t N.',
        vim.log.levels.INFO, { title = 'Терминал' })
end

function M.choose()
    local ok, current = preference()
    local title = ok and (current or 'Auto') or 'путь недоступен, используется Auto'
    vim.ui.select(choices(), {
        prompt = 'Оболочка терминала | ' .. title,
        format_item = function(item) return item.label end,
    }, function(item)
        if not item then return end
        if not item.custom then
            save(item.path)
            return
        end
        vim.ui.input({ prompt = 'Путь к бинарю оболочки ', default = ok and current or nil, completion = 'file' },
            function(input)
                if not input or vim.trim(input) == '' then return end
                local path = vim.fs.normalize(vim.fn.fnamemodify(vim.trim(input), ':p'))
                if input:find('%c') or not executable(path) then
                    vim.notify('Исполняемый файл оболочки не найден: ' .. path,
                        vim.log.levels.WARN, { title = 'Терминал' })
                    return
                end
                save(path)
            end)
    end)
end

return M
