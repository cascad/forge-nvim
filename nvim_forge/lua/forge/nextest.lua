-- spec: IDE-BOOT-49. Normal Rust tool; native RunSpec, no provisioning on startup.
local M={}
function M.executable(root,options)
    options=vim.tbl_extend('force',options or {},{root=root})
    local paths=require('forge.tool_paths')
    local path,explicit=paths.override('cargo-nextest',options)
    if explicit then return path end
    path=vim.fn.exepath('cargo-nextest')
    if path~='' then return paths.selected('cargo-nextest',path,'PATH',root) end
    local home=vim.env.CARGO_HOME
    if not home or home=='' then home=vim.fs.joinpath(vim.fn.has('win32')==1 and vim.env.USERPROFILE or vim.env.HOME,'.cargo') end
    path=vim.fs.joinpath(home,'bin','cargo-nextest'..(vim.fn.has('win32')==1 and '.exe' or ''))
    return paths.selected('cargo-nextest',vim.fn.executable(path)==1 and path or nil,'Cargo home',root)
end
function M.check(options)
    local path=assert(M.executable(nil,options or {scope='user'}),'Rust Tests: cargo-nextest отсутствует; выбери существующий tool или установи официальный nextest.')
    local r=vim.system({path,'--version'},{text=true}):wait(10000)
    assert(r.code==0 and r.signal==0 and (r.stdout or ''):find('cargo-nextest',1,true),
        'Rust Tests: cargo-nextest не готов: '..path..'\n'..(r.stderr or ''))
    return {path=path,version=vim.trim(r.stdout)}
end
function M.available(root)
    local paths=require('forge.tool_paths')
    local path,reason=paths.attempt(M.executable,root)
    if path then return path end
    paths.warn('Rust Tests: cargo-nextest недоступен. Проверь tools.json/Cargo home; :ForgeLogs.',reason,'Rust Tests')
end
function M.wrap(adapter)
    local build=adapter.build_spec
    adapter.build_spec=function(args)
        if args.strategy=='dap' then return build(args) end
        local path=M.available(args.tree:data().path)
        if not path then return nil end
        local spec=build(args)
        if spec then
            assert(type(spec.command)=='table' and spec.command[1]=='cargo' and spec.command[2]=='nextest',
                'Unexpected native nextest RunSpec')
            spec.command[1]=path -- Cargo subcommands accept the same `nextest run ...` argv directly.
        end
        return spec
    end
    return adapter
end
return M
