-- spec: IDE-LOG-2/4. Только displayed text, без notification data/env/locals.
local M = { memory = {}, limit = 200, file_limit = 128 * 1024 }
local uv = vim.uv
local sequence = 0
local notified, last_native = {}, {}
local function truncate(text,limit)
    if #text<=limit then return text end
    local cut=limit
    while text:byte(cut)>=128 and text:byte(cut)<192 do cut=cut-1 end
    return text:sub(1,cut-1)..' … [truncated]'
end

function M.clean(value)
    local text = tostring(value or '')
    text = text:gsub('([%a][%w+.-]*://)[^%s/@]+@', '%1[redacted]@')
        :gsub('([Bb]earer%s+)[%w%._~+/%-=]+', '%1[redacted]')
    local secrets = { password=true, passwd=true, token=true, api_key=true, apikey=true,
        access_token=true, secret=true, authorization=true }
    local function sensitive(key) return secrets[key:lower():gsub('["\'%-]', '')] end
    text = text:gsub('(["\']?[%w_%-]+["\']?)(%s*[:=]%s*)(["\'])(.-)%3', function(k, sep, quote, v)
        return k .. sep .. quote .. (sensitive(k) and '[redacted]' or v) .. quote
    end)
    return (text:gsub('([%w_%-]+)(%s*[:=]%s*)([^%s,;]+)', function(k, sep, v)
        return k .. sep .. (sensitive(k) and '[redacted]' or v)
    end))
end

local function files()
    local all, scan = {}, uv.fs_scandir(M.directory)
    if not scan then return all end
    while true do
        local name = uv.fs_scandir_next(scan)
        if not name then break end
        local session, pid = name:match('^(%d+%-(%d+)%-%d+)%.jsonl%.?1?$')
        if session then
            local path = M.directory .. '/' .. name
            local stat = uv.fs_lstat(path)
            if stat and stat.type == 'file' then
                all[#all + 1] = {path=path, session=session, pid=tonumber(pid), time=stat.mtime.sec}
            end
        end
    end
    table.sort(all, function(a,b) return a.time == b.time and a.path > b.path or a.time > b.time end)
    return all
end

local function trim_sessions()
    local keep, count = {}, 0
    for _, item in ipairs(files()) do
        if item.session ~= M.session and keep[item.session] == nil then
            -- Signal 0 только проверяет существование PID. Не завершаем процессы.
            local _, _, code = uv.kill(item.pid, 0)
            if code == 'ESRCH' then count=count+1; keep[item.session]=count<=8
            else keep[item.session]=true end
        end
        if keep[item.session] == false then
            local ok, err = uv.fs_unlink(item.path)
            if not ok then M.disk_error = tostring(err) end
        end
    end
end

local function append(entry)
    if not M.path then return end
    local raw = vim.json.encode(entry) .. '\n'
    local stat = uv.fs_stat(M.path)
    if stat and stat.size + #raw > M.file_limit then
        local old = uv.fs_lstat(M.path .. '.1')
        if old then assert(old.type=='file', 'History backup is not a regular file');assert(uv.fs_unlink(M.path..'.1')) end
        assert(uv.fs_rename(M.path, M.path .. '.1'))
        M.rotated = true
    end
    local fd = assert(uv.fs_open(M.path, 'a', 384))
    local written, issue = uv.fs_write(fd, raw, -1)
    local closed, close_error = uv.fs_close(fd)
    assert(written == #raw, issue or 'Incomplete history write');assert(closed, close_error)
end

function M.record(message, level, source)
    local text = M.clean(message)
    if text == '' then return end
    text=truncate(text,8192)
    sequence=sequence+1
    local entry={id=M.session..':'..sequence,session=M.session,sequence=sequence,
        time=os.time(),level=type(level)=='number' and level or vim.log.levels.INFO,
        source=truncate(M.clean(source or 'IDE'),80),message=text}
    M.memory[#M.memory+1]=entry
    if #M.memory>M.limit then table.remove(M.memory,1);M.dropped=true end
    if M.cache then
        M.cache[#M.cache+1]=entry
        if #M.cache>M.limit then table.remove(M.cache,1);M.history_truncated=true end
    end
    local ok, err=pcall(append,entry)
    if not ok then M.disk_error=tostring(err) end
    if M.changed and not M.scheduled then
        M.scheduled=true
        vim.schedule(function() M.scheduled=false;if M.changed then M.changed() end end)
    end
end

function M.entries()
    if M.cache then return M.cache end
    local entries, seen, sessions, count = {}, {}, {}, 0
    M.damaged=0
    for _, item in ipairs(files()) do
        if sessions[item.session]==nil then
            local _,_,code=uv.kill(item.pid,0)
            if code=='ESRCH' then count=count+1;sessions[item.session]=count<=8
            else sessions[item.session]=true end
        end
        if sessions[item.session] then
            local fd=uv.fs_open(item.path,'r',0)
            if fd then
                local stat=uv.fs_fstat(fd)
                local raw=stat and uv.fs_read(fd,math.min(stat.size,M.file_limit),math.max(0,stat.size-M.file_limit))
                uv.fs_close(fd)
                for line in (raw or ''):gmatch('[^\r\n]+') do
                    local ok,entry=pcall(vim.json.decode,line)
                    if ok and type(entry)=='table' and type(entry.id)=='string' and type(entry.message)=='string'
                        and type(entry.source)=='string' and type(entry.time)=='number' and type(entry.level)=='number'
                        and type(entry.session)=='string' and type(entry.sequence)=='number' then
                        if not seen[entry.id] then entry.message=M.clean(entry.message);entries[#entries+1]=entry;seen[entry.id]=true end
                    else M.damaged=M.damaged+1 end
                end
            else M.disk_error='Не удалось прочитать '..item.path end
        end
    end
    for _, entry in ipairs(M.memory) do if not seen[entry.id] then entries[#entries+1]=entry end end
    table.sort(entries,function(a,b)
        if a.time~=b.time then return a.time<b.time end
        if a.session~=b.session then return a.session<b.session end
        return a.sequence<b.sequence
    end)
    M.history_truncated=#entries>M.limit
    while #entries>M.limit do table.remove(entries,1) end
    M.cache=entries
    return entries
end

function M.reload() M.cache=nil end

-- :messages остаётся владельцем native истории. Его чтение не меняет UI.
-- Время записи таких строк — время снимка, исходный native текст сохранён.
function M.snapshot_messages()
    local current=vim.split(vim.fn.execute('200messages'),'\n',{plain=true,trimempty=true})
    for i,line in ipairs(current) do current[i]=truncate(line,8192) end
    local overlap=0
    for first=1,#last_native do
        local size=#last_native-first+1
        if size<=#current then
            local same=true
            for i=1,size do if last_native[first+i-1]~=current[i] then same=false;break end end
            if same then overlap=size;break end
        end
    end
    last_native=current
    local forwarded={}
    for _,message in ipairs(notified) do for line in message:gmatch('[^\r\n]+') do forwarded[line]=true end end
    for i=overlap+1,#current do
        local line=M.clean(current[i])
        if not forwarded[line] then
            local error_line=line:match('E%d+:') or line:find('Error detected',1,true)
            M.record(line,error_line and vim.log.levels.ERROR or vim.log.levels.INFO,'Neovim :messages (snapshot)')
        end
    end
end

function M.setup()
    if M.session then return end
    M.directory=vim.fs.joinpath(vim.fn.stdpath('state'),'forge-logs')
    M.session=string.format('%d-%d-%.0f',os.time(),uv.os_getpid(),uv.hrtime())
    M.path=M.directory..'/'..M.session..'.jsonl'
    local ok,err=pcall(function() vim.fn.mkdir(M.directory,'p');trim_sessions() end)
    if not ok then M.disk_error=tostring(err) end
    local original=vim.notify
    vim.notify=function(...)
        local message,level,opts=...
        notified[#notified+1]=truncate(M.clean(message),8192)
        if #notified>M.limit then table.remove(notified,1) end
        pcall(M.record,message,level,type(opts)=='table' and opts.title or 'IDE')
        return original(...)
    end
    vim.api.nvim_create_autocmd({'VimEnter','VimLeavePre'}, {group=vim.api.nvim_create_augroup('ForgeLogHistory',{clear=true}),
        callback=function() local success,issue=pcall(M.snapshot_messages);if not success then M.capture_error=tostring(issue) end end})
    M.record('Сессия IDE начата',vim.log.levels.INFO,'Session')
end

return M
