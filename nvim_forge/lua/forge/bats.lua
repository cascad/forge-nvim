-- spec: IDE-SH-4. Публичный Neotest adapter, без shell-строк и private API.
local M={name='forge-bats'}
local host=require('forge.bash_host')
local function file(path) return path and vim.fn.filereadable(path)==1 end
local function warn(text) vim.notify(text,vim.log.levels.WARN,{title='Bats'}) end
local function runner(path)
    local explicit=vim.g.forge_bats_executable or vim.env.FORGE_BATS_EXECUTABLE
    if explicit and explicit~='' then return file(explicit) and explicit or nil end
    local root=require('forge.bash').root(path)
    for dir in vim.fs.parents(path) do
        local candidate=dir..'/node_modules/bats/bin/bats'
        if file(candidate) then return candidate end
        if dir==root then break end
    end
    local found=vim.fn.exepath('bats')
    if found~='' then return vim.uv.fs_realpath(found) or found end
end
function M.root(path)
    local root=require('forge.bash').root(path)
    -- Neotest присоединяет native separator и сравнивает с именем buffer.
    return vim.uv.fs_realpath(root) or root
end
function M.is_test_file(path) return path:match('%.bats$')~=nil end
function M.filter_dir(name) return name~='node_modules' and name~='.git' end
function M.discover_positions(path)
    local lib=require('neotest.lib')
    local lines=vim.split(lib.files.read(path),'\n',{plain=true})
    require('nio').scheduler()
    local positions={{type='file',path=path,name=vim.fs.basename(path),range={0,0,#lines,0}}}
    -- Bats сам определяет declarations построчно (bats-preprocess), это
    -- отдельный DSL. Bash grammar не годится для @test blocks. Повторяем
    -- публичные формы header без исполнения script при discovery.
    for row,raw in ipairs(lines) do
        local line=raw:gsub('\r','')
        local name=line:match('^%s*@test%s+(.+)%s+{')
        if name then name=vim.trim(name):gsub('^["\']',''):gsub('["\']$','')
        else name=line:match('([^%s%(%)]+)%s*%(?%)?%s+{%s+#%s*@test%s*$') end
        if name then positions[#positions+1]={type='test',name=name,path=path,range={row-1,0,row-1,#line}} end
    end
    for i=2,#positions do positions[i].range[3]=positions[i+1] and positions[i+1].range[1]-1 or positions[1].range[3] end
    return lib.positions.parse_tree(positions,{})
end
local function regex(name)
    return '^'..name:gsub('.',function(c) return ('.^$*+?()[]{}|\\'):find(c,1,true) and '\\'..c or c end)..'$'
end
function M.build_spec(args)
    require('nio').scheduler()
    -- Публичный Neotest fallback разбивает file/dir на отдельные test trees.
    -- У каждого будет свой process key, результат и возможность stop/attach.
    if args.tree:data().type~='test' then return nil end
    if args.strategy=='dap' then warn('Bash DAP ещё не подготовлен (IDE-057). Обычные tests: Space T t / Space T f.');return nil end
    local pos=args.tree:data()
    local path=pos.path
    local bash,bats=host.executable(),runner(path)
    if not bash or not bats then warn('Нужны native Bash и Bats. Подготовь tools явно или задай FORGE_BASH_EXECUTABLE/FORGE_BATS_EXECUTABLE.');return nil end
    local script,err=host.path(bats,bash);if not script then warn(err);return nil end
    local env;env,err=host.environment(bash,true);if not env then warn(err);return nil end
    local test_path;test_path,err=host.path(path,bash);if not test_path then warn(err);return nil end
    local report=vim.fn.tempname()..'-bats.tap'
    local report_dir;report_dir,err=host.path(vim.fs.dirname(report),bash);if not report_dir then warn(err);return nil end
    env.BATS_REPORT_FILENAME=vim.fs.basename(report)
    local cmd={bash,'--noprofile','--norc',script,'--formatter','tap','--report-formatter','tap','--output',report_dir,
        '--show-output-of-passing-tests','--filter',regex(pos.name),test_path}
    vim.list_extend(cmd,args.extra_args or {})
    return {command=cmd,cwd=M.root(path),env=env,context={id=pos.id,line=pos.range[1],report=report}}
end
function M.results(spec,result)
    -- ConPTY может заменить newline на cursor control. Machine report Bats
    -- записан до exit и не проходит через PTY; stdout остаётся для ошибок CLI.
    local lib=require('neotest.lib')
    local tap=file(spec.context.report) and lib.files.read(spec.context.report) or ''
    local output_path=tap~='' and spec.context.report or result.output
    local output=tap~='' and tap or lib.files.read(result.output)
    -- Exit 0 при zero-match не должен превращаться в passed.
    tap='\n'..tap:gsub('\r','')..'\n'
    local passed=result.code==0 and tap:find('\n1..1\n',1,true)~=nil and tap:find('\nok 1 ',1,true)~=nil
    return {[spec.context.id]={status=passed and 'passed' or 'failed',output=output_path,
        errors=passed and {} or {{line=spec.context.line,message='Bats exit '..tostring(result.code)..'\n'..output}}}}
end
return M
