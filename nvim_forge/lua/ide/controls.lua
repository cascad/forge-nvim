-- spec: IDE-PANEL-1/2/3/4/5 общий маршрут: DAP, Outline, Neo-tree, Git.
local M = {}
local zoom, help
local active_win
local titles = {
    dapui_scopes = 'Locals', dapui_watches = 'Watch', dapui_stacks = 'Call Stack',
    dapui_breakpoints = 'Breakpoints', ['dap-repl'] = 'Output / REPL',
    dapui_console = 'Debug Console', ['dap-terminal'] = 'Debug Terminal',
    aerial = 'Outline', ['neo-tree'] = 'Files', NeogitStatus = 'Git',
}
local tree_components = { filesystem = 'explorer', buffers = 'buffers', git_status = 'git_status' }
function M.tree_component(source) return tree_components[source] end
local winbar = "%!v:lua.require'ide.controls'.winbar()"

local function valid(win) return win and vim.api.nvim_win_is_valid(win) end
local function ft(win) return vim.bo[vim.api.nvim_win_get_buf(win or 0)].filetype end
local function component(win)
    local kind = ft(win)
    if kind == 'neo-tree' then
        return tree_components[vim.b[vim.api.nvim_win_get_buf(win or 0)].neo_tree_source]
    end
    if kind:match('^dapui_') and kind ~= 'dapui_console' then return 'dap.sidebar' end
    return ({ ['dap-repl'] = 'dap.repl', dapui_console = 'dap.console', ['dap-terminal'] = 'dap.terminal', aerial = 'outline', NeogitStatus = 'neogit' })[kind]
end

local function close_help(enter)
    if not help then return end
    local old = help
    help = nil
    if valid(old.win) then vim.api.nvim_win_close(old.win, true) end
    if enter and valid(old.source) then vim.api.nvim_set_current_win(old.source) end
end

function M.restore(enter)
    if not zoom then return false end
    local old = zoom
    zoom = nil
    local cursor, view
    if valid(old.win) and valid(old.source)
        and vim.api.nvim_win_get_buf(old.win) == vim.api.nvim_win_get_buf(old.source) then
        cursor = vim.api.nvim_win_get_cursor(old.win)
        view = vim.api.nvim_win_call(old.win, vim.fn.winsaveview)
    end
    if valid(old.win) then vim.api.nvim_win_close(old.win, true) end
    if enter and valid(old.source) then vim.api.nvim_set_current_win(old.source) end
    -- WinEnter backend может восстановить прежнюю позицию. Выбор overlay
    -- переносим после возврата окна, до выполнения подтверждённого действия.
    if cursor and valid(old.source) then
        vim.api.nvim_win_set_cursor(old.source, cursor)
        vim.api.nvim_win_call(old.source, function() vim.fn.winrestview(view) end)
    end
    return true
end

-- Backend Neo-tree читает cursor по исходному окну NuiTree. Перед действием
-- вернуть туда выбранную строку overlay; команды самого backend не меняются.
function M.tree_action() if zoom and ft(0) == 'neo-tree' then M.restore(true) end end

function M.focus_code()
    close_help(false)
    M.restore(false)
    if ft(0) == 'NeogitStatus' and #vim.api.nvim_tabpage_list_wins(0) == 1 and #vim.api.nvim_list_tabpages() > 1 then
        vim.cmd('tabclose')
        return
    end
    require('ide').focus_main()
end

function M.direction(direction)
    close_help(true)
    M.restore(true)
    vim.cmd('wincmd ' .. direction)
end

function M.locals()
    close_help(false)
    M.restore(false)
    require('ide.dap').focus_section('scopes')
end

function M.output()
    close_help(false)
    M.restore(false)
    require('ide.dap').focus_output()
end

function M.outline(toggle)
    close_help(false)
    M.restore(false)
    local ide = require('ide')
    ide.focus_main() -- Aerial получает файл кода, даже при входе из другой панели.
    if toggle then ide.toggle('outline') else ide.show('outline') end
    ide.focus_slot('left')
end

function M.explorer(source, toggle)
    close_help(false)
    M.restore(false)
    local ide = require('ide')
    ide.focus_main()
    local id = tree_components[source or 'filesystem']
    if toggle then ide.toggle(id) else ide.show(id) end
    ide.focus_slot('left')
end

function M.git()
    close_help(false)
    M.restore(false)
    local ide = require('ide')
    ide.focus_main()
    ide.show('neogit')
    ide.focus_slot('right')
end

-- Neogit хранит окно backend. В overlay j/k остаются локальной навигацией;
-- перед штатной операцией вернуть туда выбранную строку. Карта берётся после
-- создания backend, без копирования списка его Git-команд и private API.
function M.git_maps(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.b[buf].forge_git_maps then return end
    vim.b[buf].forge_git_maps = true
    -- В opts остаётся q=Close: Neogit использует эту запись и для log/diff.
    -- Переопределяем только готовый status, не меняя карты прочих views.
    vim.keymap.set('n', 'q', M.hide, { buffer = buf, silent = true, nowait = true, desc = 'Panel: hide Git' })
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
        if map.callback and map.expr ~= 1 and map.expr ~= true
            and map.lhs ~= 'q' and map.lhs ~= '?' and map.lhs:lower() ~= '<esc>' then
            local callback, key = map.callback, map.lhs
            vim.keymap.set('n', key, function()
                if zoom and ft(0) == 'NeogitStatus' then
                    if key == 'j' or key == 'k' then vim.cmd('normal! ' .. vim.v.count1 .. key); return end
                    M.restore(true)
                end
                return callback()
            end, { buffer = buf, silent = map.silent == 1, nowait = map.nowait == 1, desc = map.desc })
        end
    end
end

function M.hide()
    close_help(true)
    M.restore(true)
    local id = component(0)
    if id == 'neogit' and #vim.api.nvim_tabpage_list_wins(0) == 1 and #vim.api.nvim_list_tabpages() > 1 then
        vim.cmd('tabclose')
        return
    end
    if not id then
        vim.cmd('wincmd q') -- прежний Space w q для обычного окна
        return
    end
    local ide = require('ide')
    ide.hide(id)
    -- Панель могла быть открыта штатной командой backend, вне ide.state.
    -- Закрываем именно текущий компонент, сохраняя прочие слоты менеджера.
    local comp = ide.registry.get(id)
    if comp and comp.is_open() then comp.close() end
    ide.focus_main()
end

function M.cancel()
    if M.restore(true) then return end
    M.focus_code()
end

function M.zoom()
    close_help(true)
    if M.restore(true) then return end
    local source = vim.api.nvim_get_current_win()
    if not titles[ft(source)] then return end
    local buf = vim.api.nvim_win_get_buf(source)
    if ft(source) == 'NeogitStatus' then M.git_maps(buf) end
    local view = vim.fn.winsaveview()
    local cursor = vim.api.nvim_win_get_cursor(source)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor', row = 1, col = 1, width = math.max(1, vim.o.columns - 4),
        height = math.max(1, vim.o.lines - 5), border = 'rounded',
        title = ' ' .. titles[ft(source)] .. ' | Space w z: вернуть ', title_pos = 'center',
    })
    zoom = { source = source, win = win }
    vim.api.nvim_win_set_cursor(win, cursor)
    vim.fn.winrestview(view)
end

function M.help()
    close_help(true)
    local source = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {
        (titles[ft(source)] or 'Панели') .. ' — Space w', '',
        'h / j / k / l    соседнее видимое окно',
        '0               вернуться в код',
        'd               Locals',
        'c               Output / REPL / Terminal',
        'a               Outline слева',
        'e               Files слева',
        'g               Git справа',
        'q               скрыть текущую панель',
        'z               развернуть / вернуть',
        '?               эта подсказка', '',
        'В панели: j/k — список, Enter — раскрыть/выбрать.',
        'q — скрыть; Esc — вернуть zoom, иначе фокус в код.',
        'Insert/terminal: печатные клавиши остаются вводом.',
        'Из terminal: Esc Esc — normal; F7 — в код.',
        'Навигация не продолжает и не завершает отладку.', '',
        'Закрыть помощь: q / Esc',
    }
    if ft(source) == 'aerial' then
        lines[#lines + 1] = 'Outline: j/k — выбор, Enter/o — перейти в код.'
        lines[#lines + 1] = 'h/l — свернуть/раскрыть, v/s — перейти в split.'
        lines[#lines + 1] = 'g? — полная штатная справка Aerial.'
    elseif ft(source) == 'neo-tree' then
        lines[#lines + 1] = 'Files: a/A — файл/каталог, r — имя, m — путь.'
        lines[#lines + 1] = 'x/p — вырезать/вставить, h/l — свернуть/открыть.'
        lines[#lines + 1] = 'bf/bb/bg или </> — Files/Buffers/Git, g? — справка.'
        lines[#lines + 1] = 'Диалог: Enter — подтвердить, Esc — отменить ввод.'
    elseif ft(source) == 'NeogitStatus' then
        lines[#lines + 1] = 'Git: Tab — раскрыть diff, s/u — stage/unstage.'
        lines[#lines + 1] = 'c c — commit; P u — push; b — ветки; w — worktree.'
        lines[#lines + 1] = 'g? — штатная справка Neogit со всеми действиями.'
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].filetype = 'forge-panel-help'
    vim.bo[buf].modifiable = false
    local width, height = math.min(72, vim.o.columns - 4), math.min(#lines, vim.o.lines - 5)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor', row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)), width = width, height = height,
        border = 'rounded', style = 'minimal', title = ' Управление панелью ',
    })
    help = { source = source, win = win }
    for _, key in ipairs({ 'q', '<Esc>' }) do
        vim.keymap.set('n', key, function() close_help(true) end, { buffer = buf, nowait = true, silent = true })
    end
end

function M.winbar()
    local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
    if not valid(win) then return '' end
    local title = titles[ft(win)] or 'Debug'
    if ft(win) == 'neo-tree' then
        local state = require('neo-tree.sources.manager').get_state_for_window(win)
        local prefix = win == active_win and '%#DiagnosticInfo#[focus]%* ' or ''
        if state then
            return prefix .. require('neo-tree.ui.selector').get_selector(state,
                math.max(1, vim.api.nvim_win_get_width(win) - (win == active_win and 8 or 0)))
        end
    end
    if win == active_win then return '%#DiagnosticInfo#[focus] ' .. title .. '  ? помощь%*' end
    return '%#WinBarNC# ' .. title .. '  ? помощь%*'
end

function M.refresh()
    local current = vim.api.nvim_get_current_win()
    active_win = current
    if zoom and (not valid(zoom.source) or (current ~= zoom.win and not (help and current == help.win))) then
        M.restore(false)
    end
    if help and current ~= help.win then close_help(false) end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if titles[ft(win)] then vim.wo[win].winbar = winbar end
    end
    vim.cmd('redrawstatus')
end

function M.setup()
    local group = vim.api.nvim_create_augroup('ForgePanelControls', { clear = true })
    vim.api.nvim_create_autocmd('User', {
        group = group, pattern = 'NeogitStatusRefreshed', callback = function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.bo[buf].filetype == 'NeogitStatus' then M.git_maps(buf) end
            end
        end,
    })
    vim.api.nvim_create_autocmd('FileType', {
        group = group, pattern = vim.tbl_keys(titles), callback = function(ev)
            if vim.bo[ev.buf].filetype == 'NeogitStatus' then
                return -- общие карты заданы в opts Neogit после FileType
            end
            for key, action in pairs({ q = M.hide, ['<Esc>'] = M.cancel, ['?'] = M.help }) do
                vim.keymap.set('n', key, action, { buffer = ev.buf, nowait = true, silent = true, desc = 'Panel: ' .. key })
            end
        end,
    })
    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'TabEnter', 'WinClosed' }, {
        group = group, callback = function() vim.schedule(M.refresh) end,
    })
    vim.schedule(M.refresh)
end

return M
