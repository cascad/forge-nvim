-- spec: IDE-SQL-7/8. Публичный Neotest adapter для полного SQLLogicTest script.
local M={name='forge-sqltest'}
local function normalize(path) return vim.fs.normalize(path) end
local function runner()
    local explicit=vim.g.forge_sqltest_executable or vim.env.FORGE_SQLTEST_EXECUTABLE
    if explicit and explicit~='' then return vim.fn.executable(explicit)==1 and vim.fn.exepath(explicit) or nil end
    local found=vim.fn.exepath('forge-sqltest')
    return found~='' and found or nil
end
local function warn(message) vim.notify(message,vim.log.levels.WARN,{title='SQLLogicTest'}) end
local function unavailable(pos,message)
    warn(message)
    local path=vim.fn.tempname()..'-sqltest-preflight.txt'
    require('nio').fn.writefile({message},path)
    -- Публичная Strategy сообщает настоящий configuration failure без child
    -- process. Leaf nil вызвал бы дополнительный Neotest traceback.
    return {command={},context={id=pos.id,line=pos.range[1],error=message,output=path},
        strategy=function()
            return {is_complete=function() return true end,result=function() return 2 end,
                output=function() return path end,output_stream=function() return function() end end,
                stop=function() end,attach=function() end}
        end}
end
function M.root(path)
    local root=vim.fs.root(path,{'.git','.sqls.json'}) or vim.fs.dirname(path)
    return vim.uv.fs_realpath(root) or root
end
function M.is_test_file(path) return path:match('%.slt$')~=nil end
function M.filter_dir(name)
    return not vim.tbl_contains({'.git','node_modules','target','.venv','.tools'},name)
end
function M.discover_positions(path)
    local lib=require('neotest.lib')
    local last=math.max(0,#vim.split(lib.files.read(path),'\n',{plain=true})-1)
    require('nio').scheduler()
    -- Вырванный query теряет setup/ordered state. Nearest/file имеют один
    -- leaf на весь script; общий Neotest fallback исполняет leaves для all.
    return lib.positions.parse_tree({
        {type='file',path=path,name=vim.fs.basename(path),range={0,0,last,0}},
        {type='test',path=path,name='SQLite script',range={0,0,last,0}},
    },{})
end
function M.build_spec(args)
    require('nio').scheduler()
    if args.tree:data().type~='test' then return nil end
    local pos=args.tree:data()
    if args.strategy=='dap' then
        return unavailable(pos,'SQLLogicTest не использует DAP. Запуск: Space T t / Space T f / Space T A.')
    end
    local binary=runner()
    if not binary then
        return unavailable(pos,'Нужен native SQLLogicTest SDK. Подготовь prepare_sql_test.py --download явно и задай FORGE_SQLTEST_EXECUTABLE или PATH.')
    end
    local report=vim.fn.tempname()..'-sqltest.json'
    return {command={binary,'--report',report,'--',pos.path},cwd=M.root(pos.path),
        context={id=pos.id,path=pos.path,line=pos.range[1],report=report}}
end
function M.results(spec,result)
    local lib=require('neotest.lib');require('nio').scheduler()
    local context=spec.context
    if context.error then return {[context.id]={status='failed',output=context.output,short=context.error,
        errors={{line=context.line,message=context.error}}}} end
    local ok,raw=pcall(lib.files.read,context.report)
    local decoded,data=false,nil
    if ok then decoded,data=pcall(vim.json.decode,raw) end
    local valid=decoded and type(data)=='table' and data.protocol==1 and type(data.file)=='string'
        and normalize(data.file)==normalize(context.path) and type(data.checks)=='number'
        and data.checks>=0 and data.checks%1==0 and type(data.errors)=='table' and vim.islist(data.errors) and type(data.output)=='string'
        and ((data.status=='passed' and result.code==0 and data.checks>0 and #data.errors==0)
          or (data.status=='failed' and result.code==1 and #data.errors>0))
    if valid then for _,failure in ipairs(data.errors) do
        if type(failure)~='table' or type(failure.file)~='string' or type(failure.message)~='string'
            or type(failure.line)~='number' or failure.line<1 or failure.line%1~=0 then valid=false;break end
    end end
    local passed=valid and data.status=='passed'
    local output,errors
    if valid then
        output=data.output;errors={}
        for _,failure in ipairs(data.errors) do
            local same=type(failure.file)=='string' and normalize(failure.file)==normalize(context.path)
            -- Neotest Error имеет line, но не filename. Не прикреплять line
            -- включённого script к чужой строке root; точная location в output.
            errors[#errors+1]={line=same and math.max(0,(tonumber(failure.line) or 1)-1) or context.line,
                message=tostring(failure.message or output)}
        end
    else
        -- Raw PTY output may contain clear-screen/OSC and erase this error
        -- in the terminal-based output panel. It is not a valid test report.
        output='Invalid SQLLogicTest report (runner exit '..tostring(result.code)..').'
        errors={{line=context.line,message=output}}
    end
    local output_path=context.report..'.txt'
    require('nio').fn.writefile(vim.split(output,'\n',{plain=true}),output_path)
    return {[context.id]={status=passed and 'passed' or 'failed',output=output_path,short=output,errors=errors}}
end
return M
