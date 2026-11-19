-- IDE-BOOT-50. Read-only inspection of the selected SDK; no registry/install.
local M={}
local join=vim.fs.joinpath
local suffix=vim.fn.has('win32')==1 and '.exe' or ''
local function call(command,env)
    local r=vim.system(command,{text=true,timeout=10000,env=env}):wait()
    if r.code~=0 or (r.signal or 0)~=0 then return nil,(r.stderr or '')..' (exit '..r.code..', signal '..tostring(r.signal or 0)..')' end
    return vim.trim(r.stdout or '')
end
local function normalized(path)
    path=vim.fs.normalize(vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path,':p')):gsub('/+$','')
    return suffix~='' and path:lower() or path
end
function M.inspect(rustc,scope)
    local result={schema=1,ready=false,missing={}}
    local ok,why=pcall(function()
        local selected=require('forge.sdk').selection('rust',nil,{scope=scope or 'project'})
        rustc=rustc or selected and selected.tools.rustc or vim.fn.exepath('rustc')
        assert(rustc and rustc~='' and vim.fn.executable(rustc)==1,'Rust SDK not found')
        local env=vim.tbl_extend('force',selected and selected.env or {},{RUSTUP_AUTO_INSTALL='0'})
        local sysroot,error_text=call({rustc,'--print','sysroot'},env)
        assert(sysroot and vim.fn.isdirectory(sysroot)==1,error_text or 'Invalid Rust sysroot')
        result.rustc=rustc;result.root=sysroot
        local formatter,explicit=require('forge.tool_paths').override('rustfmt',{scope=scope or 'project'})
        formatter=explicit and formatter or join(vim.fs.dirname(rustc),'rustfmt'..suffix)
        local version
        if vim.fn.executable(formatter)==1 then version=call({formatter,'--version'},env) end
        if version and version:match('^rustfmt ') then result.formatter=formatter;result.version=version
        else result.missing[#result.missing+1]='rustfmt';assert(not explicit,'Explicit rustfmt is unavailable: '..formatter) end
        result.sources=join(sysroot,'lib/rustlib/src/rust/library')
        if vim.fn.isdirectory(result.sources)~=1 then result.missing[#result.missing+1]='rust-src' end
        result.ready=#result.missing==0
        if result.ready then return end
        local home=assert(vim.uv.os_homedir())
        local rustup_home=vim.env.RUSTUP_HOME
        if not rustup_home or rustup_home=='' then rustup_home=join(home,'.rustup') end
        local base=normalized(join(rustup_home,'toolchains'))..'/'
        local actual=normalized(sysroot)
        local name=actual:sub(#base+1)
        local rustup=vim.fn.exepath('rustup')
        if rustup=='' then
            local cargo=vim.env.CARGO_HOME
            if not cargo or cargo=='' then cargo=join(home,'.cargo') end
            rustup=join(cargo,'bin','rustup'..suffix)
        end
        if actual:sub(1,#base)==base and name~='' and not name:find('/',1,true) and vim.fn.executable(rustup)==1 then
            result.repair={program=rustup,args={'component','add','--toolchain',name,'rustfmt','rust-src'},environment=env,
                source='Добавить rustfmt/rust-src через rustup для '..sysroot..'; компилятор не обновляется'}
        else
            result.error='Выбранный SDK не управляется доступным rustup. Добавь rustfmt/rust-src его штатным поставщиком или выбери полный Rust SDK.'
        end
    end)
    if not ok then result.ready=false;result.error=tostring(why) end
    return result
end
return M
