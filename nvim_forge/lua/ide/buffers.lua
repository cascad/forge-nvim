-- spec: IDE-BUF-1/2/3/4. Общая модель файлов, без управления tabpages/терминалом.
local M = {}
local recent, closed, missing = {}, {}, {}
local closing, cancelling_save = {}, {}
local deleted = {}
local disk_backed = {}
function M.may_autosave(buf)
    return cancelling_save[buf] == true or (not closing[buf] and not deleted[buf])
end
local tool_ft = {
    alpha=true, ['neo-tree']=true, aerial=true, ['dap-repl']=true,
    dapui_scopes=true, dapui_watches=true, dapui_stacks=true,
    dapui_breakpoints=true, dapui_console=true, ['dap-terminal']=true,
    ['neotest-summary']=true, ['neotest-output-panel']=true,
    OverseerList=true, ['grug-far']=true, trouble=true, qf=true, help=true,
    man=true, NeogitStatus=true, DiffviewFiles=true, DiffviewFileHistory=true,
}

local function is_document(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == ''
        and not tool_ft[vim.bo[buf].filetype]
end
function M.is_file(buf)
    return is_document(buf) and vim.bo[buf].buflisted
end

local function note_missing(buf)
    local name=vim.api.nvim_buf_get_name(buf)
    if name=='' or missing[buf]==name then return end
    missing[buf]=name
    vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) and missing[buf]==name then
            require('fidget').notify('File no longer available on disk: '..vim.fn.fnamemodify(name,':t')..
                '\nТекст сохранён в буфере; :write / :saveas или <leader>bd.',
                vim.log.levels.WARN,{annote='Files',key='missing-file:'..buf})
        end
    end)
end

local function detach_signs(buf)
    local signs=package.loaded.gitsigns
    if signs then signs.detach(buf) end
end

function M.is_editor_window(win)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= ''
        or vim.w[win].forge_panel then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[buf].filetype == 'alpha' or
        (vim.bo[buf].buftype == '' and not tool_ft[vim.bo[buf].filetype])
end

function M.editor_window()
    local current = vim.api.nvim_get_current_win()
    if M.is_editor_window(current) then return current end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if M.is_editor_window(win) then return win end
    end
    return require('ide').find_main_window()
end

function M.focus_editor() vim.api.nvim_set_current_win(M.editor_window()) end

function M.ordered()
    local out, seen = {}, {}
    local function add(buf)
        if buf and not seen[buf] and M.is_file(buf) then out[#out+1],seen[buf]=buf,true end
    end
    local ok, line = pcall(require, 'bufferline')
    if ok and type(line.get_elements)=='function' then
        local got, result = pcall(line.get_elements)
        if got then for _, item in ipairs(result.elements or {}) do add(tonumber(item.id)) end end
    end
    -- BufferLine может ещё не отрисовать badd/BufEnter. Их нельзя терять.
    for _, info in ipairs(vim.fn.getbufinfo({buflisted=1})) do add(info.bufnr) end
    return out
end

function M.show(buf)
    if not M.is_file(buf) then return end
    M.focus_editor()
    vim.api.nvim_set_current_buf(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= '' and vim.fn.filereadable(name)==0 then note_missing(buf)
    elseif not deleted[buf] then missing[buf]=nil end
end

function M.cycle(direction)
    local files = M.ordered()
    if #files==0 then return end
    local active = vim.api.nvim_win_get_buf(M.editor_window())
    local index
    for i, buf in ipairs(files) do if buf==active then index=i;break end end
    M.show(files[index and ((index-1+direction)%#files)+1 or 1])
end

function M.open_alpha_screen()
    local ok, alpha = pcall(require, 'alpha')
    if ok then alpha.start(false) else vim.cmd.enew() end
end

function M.other_files(except)
    return vim.tbl_filter(function(buf) return buf~=except end,M.ordered())
end

local function close_file(win,buf,opts)
    -- Решение пользователя принимается до переключения окон и alpha.
    if vim.bo[buf].modified and not opts.force then
        local name=vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf),':t')
        local choice=vim.fn.confirm('Сохранить изменения: '..(name~='' and name or '[No Name]')..'?',
            '&Save\n&Discard\n&Cancel',3)
        if choice==1 then
            local ok, err=pcall(vim.api.nvim_buf_call,buf,function() vim.cmd('silent write') end)
            if not ok then
                vim.notify('Не удалось сохранить буфер: '..tostring(err),vim.log.levels.WARN,{title='Files'})
                return false
            end
        elseif choice~=2 then return false end
    end
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    local entry={path=vim.api.nvim_buf_get_name(buf),cursor=vim.api.nvim_win_get_cursor(win)}
    local target=M.other_files(buf)[1]
    for _, candidate in ipairs(recent) do
        if candidate~=buf and M.is_file(candidate) then target=candidate;break end
    end
    local windows={}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(w)==buf then windows[#windows+1]=w end
    end
    vim.api.nvim_set_current_win(win)
    if not target then M.open_alpha_screen();target=vim.api.nvim_get_current_buf() end
    for _, w in ipairs(windows) do
        if vim.api.nvim_win_is_valid(w) then vim.api.nvim_win_set_buf(w,target) end
    end
    local ok, err=pcall(vim.api.nvim_buf_delete,buf,{force=true})
    if not ok then
        for _, w in ipairs(windows) do
            if vim.api.nvim_win_is_valid(w) and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_win_set_buf(w,buf) end
        end
        vim.notify('Не удалось закрыть буфер: '..tostring(err),vim.log.levels.WARN,{title='Files'})
        return false
    end
    local stat=entry.path~='' and vim.uv.fs_stat(entry.path)
    if stat and stat.type=='file' then
        closed[#closed+1]=entry
        if #closed>20 then table.remove(closed,1) end
    end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
    return true
end

function M.close(opts)
    opts=opts or {}
    local win=M.editor_window()
    local buf=vim.api.nvim_win_get_buf(win)
    if not M.is_file(buf) or closing[buf] then return false end
    closing[buf]=true
    local ok, result=pcall(function()
        -- Штатный cancel_deferred_save авто-save получает именно целевой
        -- буфер. BufLeave вокруг этого вызова уже защищён условием closing.
        vim.api.nvim_buf_call(buf,function()
            cancelling_save[buf]=true
            local fired, err=pcall(vim.api.nvim_exec_autocmds,'User',{pattern='ForgeBufferClose',modeline=false})
            cancelling_save[buf]=nil
            if not fired then error(err) end
        end)
        return close_file(win,buf,opts)
    end)
    closing[buf],cancelling_save[buf]=nil,nil
    if not ok then
        vim.notify('Не удалось закрыть буфер: '..tostring(result),vim.log.levels.WARN,{title='Files'})
        return false
    end
    return result
end

function M.reopen()
    local entry=table.remove(closed)
    if not entry then return end
    local stat=vim.uv.fs_stat(entry.path)
    if not stat or stat.type~='file' then
        vim.notify('Закрытый файл больше недоступен: '..vim.fn.fnamemodify(entry.path,':t'),vim.log.levels.WARN)
        return
    end
    local buf=vim.fn.bufadd(entry.path)
    vim.bo[buf].buflisted=true
    M.show(buf)
    local row=math.min(entry.cursor[1],vim.api.nvim_buf_line_count(buf))
    local line=vim.api.nvim_buf_get_lines(buf,row-1,row,false)[1] or ''
    vim.api.nvim_win_set_cursor(0,{row,math.min(entry.cursor[2],#line)})
end

function M.setup()
    local group=vim.api.nvim_create_augroup('ForgeFileBufferHistory',{clear=true})
    vim.api.nvim_create_autocmd('FileChangedShell',{group=group,callback=function(ev)
        if vim.v.fcs_reason=='deleted' and is_document(ev.buf)
            and vim.api.nvim_buf_get_name(ev.buf)~='' then
            local first_deletion=not deleted[ev.buf]
            deleted[ev.buf]=true
            note_missing(ev.buf)
            detach_signs(ev.buf)
            -- Общий :checktime проверяет только видимые окна. При удалении
            -- каталога освобождаем watchers скрытых загруженных файлов тоже;
            -- явный :checktime N затем штатно отменит их pending autosave.
            for buf,name in pairs(first_deletion and disk_backed or {}) do
                if buf~=ev.buf and not deleted[buf] and is_document(buf)
                    and vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf)==name
                    and not vim.uv.fs_stat(name) then
                    deleted[buf]=true
                    detach_signs(buf)
                    note_missing(buf)
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(buf) and deleted[buf] then
                            vim.cmd.checktime(tostring(buf))
                        end
                    end)
                end
            end
            -- AutoSave отменяет pending timer в том же native событии для
            -- ev.buf, включая скрытый буфер. В FileChangedShell нельзя
            -- переключать буферы; Post при ignore вообще не вызывается.
            cancelling_save[ev.buf]=true
            vim.schedule(function() cancelling_save[ev.buf]=nil end)
            vim.v.fcs_choice=''
        elseif vim.v.fcs_choice=='' then
            -- Наличие handler отключает default для ВСЕХ причин. Сохраняем
            -- native warning/выбор при конфликте, mode/time и т.п.
            vim.v.fcs_choice='ask'
        end
    end})
    vim.api.nvim_create_autocmd({'BufWritePost','BufWipeout'},{group=group,callback=function(ev)
        deleted[ev.buf],missing[ev.buf]=nil,nil
        if ev.event=='BufWipeout' then disk_backed[ev.buf]=nil
        else disk_backed[ev.buf]=vim.api.nvim_buf_get_name(ev.buf) end
    end})
    vim.api.nvim_create_autocmd('BufReadPost',{group=group,callback=function(ev)
        disk_backed[ev.buf]=vim.api.nvim_buf_get_name(ev.buf)
    end})
    vim.api.nvim_create_autocmd('BufFilePost',{group=group,callback=function(ev)
        missing[ev.buf]=nil
    end})
    vim.api.nvim_create_autocmd('BufEnter',{group=group,callback=function(ev)
        if not M.is_file(ev.buf) then return end
        for i=#recent,1,-1 do if recent[i]==ev.buf then table.remove(recent,i) end end
        table.insert(recent,1,ev.buf)
    end})
end

return M
