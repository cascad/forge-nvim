-- spec: IDE-LOG-2/4. Читать штатные источники, не загружая их backend.
local M={limit=64*1024}
local uv=vim.uv
local function tail(raw)
    local text=raw:sub(-M.limit)
    local first=1
    while first<=#text and text:byte(first)>=128 and text:byte(first)<192 do first=first+1 end
    return text:sub(first)
end
local function join(base,name) return vim.fs.joinpath(vim.fn.stdpath(base),name) end
local function loaded_path(module,key,fallback)
    local mod=package.loaded[module]
    if mod and type(mod[key])=='function' then local ok,path=pcall(mod[key]);if ok and type(path)=='string' then return path end end
    return fallback
end
function M.list()
    local fidget=package.loaded['fidget.logger']
    local neogit=package.loaded['neogit.logger']
    local out={
        {id='events',title='IDE — общая история',hint='Сообщения всех подсистем; s — подробный источник'},
        {id='messages',title='Neovim :messages',hint='Штатная история текущей сессии'},
        {id='nvim',title='Neovim log',path=vim.env.NVIM_LOG_FILE or join('log','log'),hint='Native журнал Neovim'},
        {id='lsp',title='LSP',path=loaded_path('vim.lsp.log','get_filename',join('log','lsp.log')),hint=':checkhealth vim.lsp; :LspLog'},
        {id='dap',title='DAP',path=join('cache','dap.log'),hint=':DapShowLog; уровень остаётся прежним'},
        {id='format',title='Format / Conform',path=loaded_path('conform.log','get_logfile',join('log','conform.log')),hint=':ConformInfo; :checkhealth forge'},
        {id='tests',title='Tests / Neotest',path=join('log','neotest.log'),hint='Space w t / r — Tests / Test Output'},
        {id='git',title='Git / Neogit',path=join('cache','neogit.log'),
            disabled=not (neogit and neogit.config.use_file or vim.env.NEOGIT_LOG_FILE),hint='Space w g, $ — native command history; file logging по умолчанию выключен'},
        {id='tasks',title='Tasks / Overseer',path=loaded_path('overseer.log','get_logfile',join('log','overseer.log')),hint='Space w b — задачи; вывод запущенных jobs в каналах ниже'},
        {id='setup',title='Setup / Mason',path=join('log','mason.log'),hint=':Mason — явная подготовка tools'},
        {id='fidget',title='Fidget',path=fidget and fidget.options.path or join('cache','fidget.nvim.log'),hint='Direct уведомления также доступны в общей истории'},
    }
    for _,path in ipairs(vim.fn.globpath(vim.fn.stdpath('cache'),'dap*.log',false,true)) do
        if vim.fs.normalize(path)~=vim.fs.normalize(join('cache','dap.log')) then
            out[#out+1]={id='dap:'..path,title='DAP / '..vim.fs.basename(path),path=path,hint='Существующий native adapter log'}
        end
    end
    local kinds={['dap-repl']=true,['dap-terminal']=true,['dapui_console']=true,
        ['neotest-output-panel']=true,['neotest-output']=true,toggleterm=true,OverseerOutput=true,['forge-sql']=true}
    for _,buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and (kinds[vim.bo[buf].filetype]
            or vim.bo[buf].buftype=='terminal') then
            out[#out+1]={id='buffer:'..buf,title='Output / '..vim.bo[buf].filetype..' #'..buf,buf=buf,
                hint='Существующий buffer; просмотр не запускает и не останавливает job'}
        end
    end
    return out
end

function M.read(source)
    local result={lines={},status='доступен',path=source.path,hint=source.hint}
    if source.id=='messages' then
        local raw=vim.fn.execute('200messages')
        result.truncated=#raw>M.limit;result.lines=vim.split(tail(raw),'\n',{plain=true})
    elseif source.buf then
        if not vim.api.nvim_buf_is_loaded(source.buf) then result.status='buffer больше недоступен';return result end
        local total=vim.api.nvim_buf_line_count(source.buf)
        local lines=vim.api.nvim_buf_get_lines(source.buf,math.max(0,total-500),-1,false)
        local raw=table.concat(lines,'\n')
        result.truncated=total>500 or #raw>M.limit
        result.lines=vim.split(tail(raw),'\n',{plain=true})
        result.path=vim.api.nvim_buf_get_name(source.buf)
    else
        local stat=source.path and uv.fs_stat(source.path)
        if not stat or stat.type~='file' then
            result.status=source.disabled and 'отключён; файл не найден' or 'файл не найден'
            return result
        end
        result.mtime=os.date('%Y-%m-%d %H:%M:%S',stat.mtime.sec)
        if source.disabled then result.status='исторический файл; текущий logger отключён' end
        local fd,err=uv.fs_open(source.path,'r',0)
        if not fd then result.status='ошибка чтения: '..tostring(err);return result end
        local offset=math.max(0,stat.size-M.limit)
        local raw,issue=uv.fs_read(fd,math.min(stat.size,M.limit),offset)
        uv.fs_close(fd)
        if not raw then result.status='ошибка чтения: '..tostring(issue);return result end
        if offset>0 then
            local complete=raw:match('\n(.+)')
            raw=complete or tail(raw)
            if not complete then result.status=result.status..'; хвост длинной строки' end
            result.truncated=true
        end
        result.lines=vim.split(raw,'\n',{plain=true})
    end
    if #result.lines==0 or (#result.lines==1 and result.lines[1]=='') then
        result.status=result.status..'; пусто'
    end
    return result
end
return M
