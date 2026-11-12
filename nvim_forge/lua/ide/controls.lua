-- spec: IDE-PANEL-1/2/3/4/5/6/7/8/17 общий маршрут рабочих панелей.
local M = {}
local zoom, help
local active_win
local pending_panel
local work = { ['neotest-summary']='tests', ['neotest-output-panel']='tests_output',
    ['grug-far']='search', OverseerList='tasks_output', ['forge-sql']='sql.results',
    toggleterm='terminal', trouble='trouble', ['forge-logs']='logs' }
local backend_maps = {}
local search_actions = { Goto=true, Open=true, ['Open Next']=true, ['Open Prev']=true, Preview=true }
local titles = {
    dapui_scopes = 'Locals', dapui_watches = 'Watch', dapui_stacks = 'Call Stack',
    dapui_breakpoints = 'Breakpoints', ['dap-repl'] = 'Output / REPL',
    dapui_console = 'Debug Console', ['dap-terminal'] = 'Debug Terminal',
    aerial = 'Outline', ['neo-tree'] = 'Files', NeogitStatus = 'Git',
    ['neotest-summary']='Tests', ['neotest-output-panel']='Test Output', ['forge-logs']='IDE Logs',
    ['grug-far']='Search', OverseerList='Tasks', ['forge-sql']='SQL Results',
    toggleterm='Terminal', trouble='Problems / Trouble',
}
local tree_components = { filesystem = 'explorer', buffers = 'buffers', git_status = 'git_status' }
function M.tree_component(source) return tree_components[source] end
local winbar = "%!v:lua.require'ide.controls'.winbar()"

local function valid(win) return win and vim.api.nvim_win_is_valid(win) end
local function ft(win) return vim.bo[vim.api.nvim_win_get_buf(win or 0)].filetype end
local function component(win)
    local kind = ft(win)
    if work[kind] then return work[kind] end
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

-- spec: IDE-PANEL-24. Один заголовок в native рамке общего zoom.
local function refresh_zoom()
    if not zoom or not valid(zoom.win) then return end
    local focused = vim.api.nvim_get_current_win() == zoom.win
    local highlight = focused and 'DiagnosticInfo' or 'Comment'
    local title = ' ' .. (titles[ft(zoom.win)] or 'Панель')
        .. (focused and ' [focus]' or '') .. ' | Space w z: вернуть '
    vim.api.nvim_win_set_config(zoom.win, { title = { { title, highlight } }, title_pos = 'center' })
    local highlights = {}
    for _, entry in ipairs(vim.split(vim.wo[zoom.win].winhl, ',', { trimempty = true })) do
        if not entry:match('^FloatBorder:') then highlights[#highlights + 1] = entry end
    end
    highlights[#highlights + 1] = 'FloatBorder:' .. highlight
    vim.wo[zoom.win].winhl = table.concat(highlights, ',')
    vim.wo[zoom.win].winbar = ''
end

function M.restore(enter)
    local pilot=package.loaded['forge.frame_pilot']
    if pilot and pilot.restore() then return true end
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

-- Общая подготовка явного перехода. enter сохраняет прежний выбор окна
-- при закрытии справки и возврате из zoom.
local function prepare_navigation(enter)
    pending_panel = nil
    close_help(enter)
    M.restore(enter)
end

function M.focus_code()
    prepare_navigation(false)
    local pilot=package.loaded['forge.frame_pilot']
    if pilot and pilot.focus_code() then return end
    if ft(0) == 'NeogitStatus' and #vim.api.nvim_tabpage_list_wins(0) == 1 and #vim.api.nvim_list_tabpages() > 1 then
        vim.cmd('tabclose')
        return
    end
    require('ide').focus_main()
end

function M.direction(direction)
    prepare_navigation(true)
    local pilot=package.loaded['forge.frame_pilot']
    if pilot and pilot.direction(direction) then return end
    vim.cmd('wincmd ' .. direction)
end

function M.locals()
    prepare_navigation(false)
    require('ide.dap').focus_section('scopes')
end

function M.output()
    prepare_navigation(false)
    require('ide.dap').focus_output()
end

function M.outline(toggle)
    prepare_navigation(false)
    local ide = require('ide')
    ide.focus_main() -- Aerial получает файл кода, даже при входе из другой панели.
    if toggle then ide.toggle('outline') else ide.show('outline') end
    ide.focus_slot('left')
end

function M.explorer(source, toggle)
    prepare_navigation(false)
    local ide = require('ide')
    ide.focus_main()
    local id = tree_components[source or 'filesystem']
    if toggle then ide.toggle(id) else ide.show(id) end
    ide.focus_slot('left')
end

function M.git()
    prepare_navigation(false)
    local ide = require('ide')
    ide.focus_main()
    ide.show('neogit')
    ide.focus_slot('right')
end

local function show_work(id)
    close_help(false)
    M.restore(false)
    local ide = require('ide')
    ide.focus_main()
    pending_panel = id
    ide.show(id)
    local comp = ide.registry.get(id)
    if comp.is_open() then pending_panel = nil;comp.focus() end
end
function M.tests() show_work('tests') end
function M.test_output() show_work('tests_output') end
function M.search() show_work('search') end
function M.tasks() show_work('tasks_output') end
function M.sql_results() show_work('sql.results') end
function M.terminal() show_work('terminal') end
function M.problems() show_work('trouble') end
function M.logs() show_work('logs') end

-- Перед native действием вернуть выбранный cursor в обычное окно backend.
-- Grug-far ищет окно через bufwinid; его карты ввода текста не трогаем.
local function trouble_view(buf)
    -- Native help использует тот же filetype, но не имеет window metadata view.
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.w[win].trouble then return true end
    end
    return false
end
function M.work_maps(buf)
    if not vim.api.nvim_buf_is_valid(buf) or not work[vim.bo[buf].filetype] then return end
    local kind = vim.bo[buf].filetype
    if kind == 'trouble' and not trouble_view(buf) then return end
    if kind == 'trouble' then
        -- Штатная справка остаётся доступна после общего normal ?.
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf,'n')) do
            if map.lhs == '?' and map.callback and map.callback ~= M.help then
                vim.keymap.set('n','g?',map.callback,{buffer=buf,nowait=true,silent=true,desc=map.desc})
            end
        end
    end
    for key, action in pairs({ q=M.hide, ['<Esc>']=M.cancel, ['?']=M.help }) do
        vim.keymap.set('n',key,action,{buffer=buf,nowait=true,silent=true,desc='Panel: '..key})
    end
    if kind ~= 'OverseerList' and kind ~= 'grug-far' and kind ~= 'trouble' then return end
    backend_maps[buf] = backend_maps[buf] or {}
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf,'n')) do
        if map.callback and map.expr~=1 and map.expr~=true and map.lhs~='q' and map.lhs~='?'
            and map.lhs:lower()~='<esc>' and map.lhs~='j' and map.lhs~='k'
            and (kind=='OverseerList' or kind=='trouble' or search_actions[map.desc])
            and backend_maps[buf][map.lhs]~=map.callback then
            local callback=map.callback
            local wrapped=function()
                if zoom and ft(0)==kind then M.restore(true) end
                return callback()
            end
            backend_maps[buf][map.lhs]=wrapped
            vim.keymap.set('n',map.lhs,wrapped,{buffer=buf,silent=map.silent==1,nowait=map.nowait==1,desc=map.desc})
        end
    end
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
    prepare_navigation(true)
    if ft(0) == 'toggleterm' or ft(0) == 'trouble' then
        -- q скрывает текущую view; registry close при смене slot закрывает группу.
        -- Буфер/job сохраняются, native WinClosed выполняет backend cleanup.
        local source = vim.api.nvim_get_current_win()
        M.focus_code()
        if valid(source) then vim.api.nvim_win_close(source,true) end
        return
    end
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
    ide.focus_main()
end

function M.cancel()
    pending_panel = nil
    if M.restore(true) then return end
    M.focus_code()
end

function M.zoom()
    pending_panel = nil
    close_help(true)
    if M.restore(true) then return end
    local pilot=package.loaded['forge.frame_pilot']
    if pilot and pilot.zoom() then return end
    local source = vim.api.nvim_get_current_win()
    if not titles[ft(source)] then return end
    local buf = vim.api.nvim_win_get_buf(source)
    if ft(source) == 'NeogitStatus' then M.git_maps(buf) end
    local view = vim.fn.winsaveview()
    local cursor = vim.api.nvim_win_get_cursor(source)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor', row = 1, col = 1, width = math.max(1, vim.o.columns - 4),
        height = math.max(1, vim.o.lines - 5), border = 'rounded',
    })
    -- spec: IDE-PANEL-18. Исключение только overlay, shared buffer остаётся в slot.
    vim.w[win].edgy_disable = true
    zoom = { source = source, win = win }
    refresh_zoom()
    vim.api.nvim_win_set_cursor(win, cursor)
    vim.fn.winrestview(view)
end

function M.help()
    pending_panel = nil
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
        't / r           Tests / Test Output',
        'f / b           Search / Tasks',
        'T / x           Terminal / Problems',
        'i               IDE Logs — сообщения и подробные журналы',
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
    elseif ft(source) == 'neotest-summary' then
        lines[#lines + 1] = 'Tests: Enter — раскрыть, i — код выбранного теста.'
        lines[#lines + 1] = 'r — запустить, o — вывод; g? — native справка.'
    elseif ft(source) == 'neotest-output-panel' then
        lines[#lines + 1] = 'Test Output: q скрывает, Space w r возвращает вывод.'
    elseif ft(source) == 'OverseerList' then
        lines[#lines + 1] = 'Tasks: Enter — действие, o — вывод, Ctrl+s/v — split.'
        lines[#lines + 1] = 'q скрывает список, job продолжает работу; g? — справка.'
    elseif ft(source) == 'grug-far' then
        lines[#lines + 1] = 'Search: i — ввод, Tab — поле, Enter — найденное место.'
        lines[#lines + 1] = 'q скрывает с сохранением запроса; g? — search/replace.'
    elseif ft(source) == 'forge-sql' then
        lines[#lines + 1] = 'SQL: Space j o — output, j q — запрос из кода, j x — stop session.'
        lines[#lines + 1] = 'q скрывает результаты; повторное открытие не выполняет SQL.'
    elseif ft(source) == 'toggleterm' then
        lines[#lines + 1] = 'Terminal: i — ввод; Ctrl-\\ Ctrl-n / Esc Esc — normal.'
        lines[#lines + 1] = 'q скрывает окно с живым job; Space w T возвращает терминал.'
        lines[#lines + 1] = 'Ctrl-t / Space tt — прежний toggle; F7 — в код.'
    elseif ft(source) == 'forge-logs' then
        lines[#lines + 1] = 'IDE Logs: s — источник, f — текст, v — уровень, c — сброс.'
        lines[#lines + 1] = 'r — обновить, Enter — детали, y — отчёт, H — health.'
        lines[#lines + 1] = '/ — обычный поиск; Space w i возвращает консоль.'
    elseif ft(source) == 'trouble' then
        lines[#lines + 1] = 'Problems: Enter — перейти, zo/zc — раскрыть/свернуть.'
        lines[#lines + 1] = 'Space xx/xQ — diagnostics/Quickfix; g? — native справка.'
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
    if pending_panel then
        local ide=require('ide')
        local id=pending_panel
        local comp=ide.registry.get(id)
        if comp and comp.is_open() then
            pending_panel=nil
            if ide.current().slots[comp.slot]==id then comp.focus() end
        end
    end
    local current = vim.api.nvim_get_current_win()
    active_win = current
    local source_gone = zoom and not valid(zoom.source)
    if zoom and (not valid(zoom.source) or (current ~= zoom.win and not (help and current == help.win))) then
        M.restore(false)
        if source_gone then M.focus_code() end
    end
    if help and current ~= help.win then close_help(false) end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local pilot=package.loaded['forge.frame_pilot']
        if pilot and pilot.owns(win) then
            pilot.refresh()
        elseif zoom and win == zoom.win then
            refresh_zoom()
        elseif titles[ft(win)] and (ft(win)~='trouble' or trouble_view(vim.api.nvim_win_get_buf(win))) then
            vim.wo[win].winbar = winbar
        end
        if work[ft(win)] then M.work_maps(vim.api.nvim_win_get_buf(win)) end
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
            if work[vim.bo[ev.buf].filetype] then
                vim.schedule(function() M.work_maps(ev.buf) end)
                return
            end
            for key, action in pairs({ q = M.hide, ['<Esc>'] = M.cancel, ['?'] = M.help }) do
                vim.keymap.set('n', key, action, { buffer = ev.buf, nowait = true, silent = true, desc = 'Panel: ' .. key })
            end
        end,
    })
    vim.api.nvim_create_autocmd('BufWipeout',{group=group,callback=function(ev) backend_maps[ev.buf]=nil end})
    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'TabEnter', 'WinClosed' }, {
        group = group, callback = function() vim.schedule(M.refresh) end,
    })
    vim.schedule(M.refresh)
end

return M
