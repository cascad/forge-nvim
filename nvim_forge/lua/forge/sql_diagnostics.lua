-- spec: IDE-SQL-2. IDE-064: native CLI сохраняет parse errors и dialect,
-- которые LSP Sqruff 0.44.0 теряет. Один cancellable debounce на buffer.
local M={namespace=vim.api.nvim_create_namespace('forge.sql.sqruff')}
local pending={}
local function cancel(buf)
    local old=pending[buf]
    pending[buf]=nil
    if not old then return end
    if old.timer and not old.timer:is_closing() then old.timer:stop();old.timer:close() end
    if old.process then old.process:kill(15) end
end
local function queue(buf)
    cancel(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype~='sql' or vim.bo[buf].buftype~='' then return end
    local sql=require('forge.sql');local tool=sql.tool('sqruff')
    if not tool then vim.diagnostic.reset(M.namespace,buf);return end
    local entry={tick=vim.api.nvim_buf_get_changedtick(buf)};pending[buf]=entry
    entry.timer=vim.defer_fn(function()
        entry.timer=nil
        if pending[buf]~=entry or not vim.api.nvim_buf_is_valid(buf) then return end
        local path=vim.api.nvim_buf_get_name(buf)
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local command=vim.list_extend({tool,'lint','--parsing-errors','--format','json','--stdin-filename',path},sql.dialect_args(path))
        command[#command+1]='-'
        entry.process=vim.system(command,{cwd=sql.root(path),stdin=table.concat(lines,'\n')..'\n',text=true,timeout=10000},function(result)
            vim.schedule(function()
                if pending[buf]~=entry then return end
                pending[buf]=nil
                if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf)~=entry.tick then return end
                local ok,data=pcall(vim.json.decode,result.stdout or '')
                if not ok or type(data)~='table' then
                    vim.notify('Sqruff: '..vim.trim(result.stderr or 'Нет JSON diagnostics.'),vim.log.levels.WARN)
                    return
                end
                local diagnostics={}
                for _,items in pairs(data) do for _,d in ipairs(items) do
                    local pos=d.range.start;local row=math.max(0,pos.line-1)
                    local line=lines[row+1] or ''
                    diagnostics[#diagnostics+1]={lnum=row,col=vim.str_byteindex(line,'utf-32',math.max(0,pos.character-1),false),
                        message=d.message,severity=d.severity=='Error' and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
                        code=d.code~=vim.NIL and d.code or nil,source='sqruff'}
                end end
                vim.diagnostic.set(M.namespace,buf,diagnostics)
            end)
        end)
    end,500)
end
function M.setup()
    local group=vim.api.nvim_create_augroup('ForgeSqlDiagnostics',{clear=true})
    vim.api.nvim_create_autocmd({'FileType','BufReadPost','TextChanged','TextChangedI','BufWritePost'},
        {group=group,callback=function(ev) queue(ev.buf) end})
    vim.api.nvim_create_autocmd('BufUnload',{group=group,callback=function(ev) cancel(ev.buf) end})
    vim.api.nvim_create_autocmd('VimLeavePre',{group=group,callback=function() for buf in pairs(pending) do cancel(buf) end end})
end
return M
