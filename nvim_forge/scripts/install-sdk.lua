-- IDE-BOOT-50. Explicit native SDK installation, only after frontend confirmation.
local kind,report,mise=unpack(arg)
assert(kind=='go' or kind=='rust' or (mise and (kind=='node' or kind=='python')),'Unsupported SDK provider')
local windows=vim.fn.has('win32')==1
local suffix=windows and '.exe' or ''
assert(kind=='rust' or vim.fn.has('linux')==1,'SDK provider requires Linux; other OS use their native managers')
local uv,join=vim.uv,vim.fs.joinpath
local readonly={MISE_AUTO_INSTALL='false',MISE_EXEC_AUTO_INSTALL='false',MISE_NOT_FOUND_AUTO_INSTALL='false',
    GOTOOLCHAIN='local',GO111MODULE='off',GOENV='off',GOWORK='off',RUSTUP_AUTO_INSTALL='0',NODE_OPTIONS=''}
local executable_name=({go='go',rust='rustc',node='node',python='python3'})[kind]
local function run(command,options)
    options=vim.tbl_extend('force',{text=true,timeout=180000},options or {})
    local result=vim.system(command,options):wait()
    if result.code~=0 or (result.signal or 0)~=0 then
        error(table.concat(command,' ')..' failed: exit='..tostring(result.code)..' signal='..tostring(result.signal)..'\n'..(result.stderr or ''),0)
    end
    if result.stderr and result.stderr~='' then io.stderr:write(result.stderr);io.stderr:flush() end
    return vim.trim(result.stdout or '')
end
local function write(path,value)
    local f=assert(io.open(path,'wb'));assert(f:write(value));assert(f:close())
end
local function ready(bin)
    local executable=join(bin,executable_name..suffix)
    if kind=='python' and vim.fn.executable(executable)~=1 then executable=join(bin,'python'..suffix) end
    if vim.fn.executable(executable)~=1 then return end
    local environment=vim.tbl_extend('force',readonly,{PATH=bin..(windows and ';' or ':')..(vim.env.PATH or '')})
    local ok,version
    if kind=='go' then
        ok,version=pcall(run,{executable,'version'},{timeout=10000,env=environment})
        if not ok or not version:match('^go version go%d') then return end
    elseif kind=='rust' then
        ok,version=pcall(run,{executable,'--version'},{timeout=10000,env=environment})
        if not ok or not version:match('^rustc %d') or vim.fn.executable(join(bin,'cargo'..suffix))~=1 then return end
    else
        ok,version=pcall(run,{executable,'--version'},{timeout=10000,env=environment})
        if not ok or not version:match(kind=='node' and '^v%d+%.%d+%.%d+' or '^Python 3%.') then return end
        if kind=='node' then
            local npm_ok=pcall(run,{join(bin,'npm'),'--version'},{timeout=10000,env=environment})
            if not npm_ok then return end
        end
    end
    return version
end
local function finish(bin,reused)
    local version=assert(ready(bin),'Installed SDK is not ready: '..bin)
    local tools,env=vim.empty_dict(),vim.empty_dict()
    if kind=='go' then
        tools.go=join(bin,'go'..suffix)
        env.GOROOT=run({tools.go,'env','GOROOT'},{timeout=10000,env=vim.tbl_extend('force',readonly,{GOROOT=''})})
    elseif kind=='rust' then
        tools.rustc=join(bin,'rustc'..suffix);tools.cargo=join(bin,'cargo'..suffix)
    elseif kind=='node' then
        tools.node=join(bin,'node');tools.npm=join(bin,'npm')
    else
        local python=join(bin,'python3')
        if vim.fn.executable(python)~=1 then python=join(bin,'python') end
        tools.python=python;tools.python3=python
    end
    write(report,vim.json.encode({schema=1,kind=kind,ready=true,bin=bin,version=version,reused=reused,
        selection={tools=tools,bin=bin,env=env,source=mise and 'native Mise SDK provider' or 'native SDK provider'}})..'\n')
    print('SDK '..kind..': '..version..' | '..bin..(reused and ' (existing version preserved)' or ''))
end
local stage,reserved
local ok,why=xpcall(function()
    assert(report and vim.fn.filereadable(report)==0,'Use a new SDK result file')
    local inherited=vim.fn.exepath(executable_name)
    if inherited=='' and kind=='python' then inherited=vim.fn.exepath('python') end
    if inherited~='' and ready(vim.fs.dirname(inherited)) then finish(vim.fs.dirname(inherited),true);return end
    if mise then
        assert(vim.fn.executable(mise)==1,'Mise executable is unavailable: '..mise)
        -- Native config resolution retains project versions/options and trust.
        -- A bare install never writes mise.toml or changes global defaults.
        local configured=vim.json.decode(run({mise,'ls','--current','--json',kind},{env=readonly}))
        local tool=#configured>0 and kind or kind..'@latest'
        local found,path=pcall(run,{mise,'where',tool},{env=readonly,timeout=10000})
        if found and ready(join(path,'bin')) then finish(join(path,'bin'),true);return end
        print('Mise: install '..tool..' | project '..vim.fn.getcwd());io.stdout:flush()
        run({mise,'install','--jobs','2',tool},{env=readonly,timeout=900000})
        local root=run({mise,'where',tool},{env=readonly,timeout=10000})
        assert(vim.fn.isdirectory(root)==1,'Mise returned an unavailable SDK directory: '..root)
        finish(join(root,'bin'),false)
        return
    end
    local home=assert(uv.os_homedir(),'Native home unavailable')
    local curl={'curl','--fail','--silent','--show-error','--location','--proto','=https','--tlsv1.2','--connect-timeout','15','--max-time','180'}
    local function fetch(url,file)
        local command=vim.deepcopy(curl);command[#command+1]=url
        if file then command[#command+1]='--output';command[#command+1]=file end
        return run(command)
    end
    if kind=='go' then
        local machine=uv.os_uname().machine
        local arch=({x86_64='amd64',aarch64='arm64',arm64='arm64'})[machine]
        assert(arch,'Unsupported Linux architecture: '..tostring(machine))
        local releases=vim.json.decode(fetch('https://go.dev/dl/?mode=json'))
        local chosen,asset
        for _,release in ipairs(releases) do
            if release.stable and type(release.version)=='string' and release.version:match('^go%d+%.%d+%.?%d*$') then
                for _,file in ipairs(release.files or {}) do
                    if file.os=='linux' and file.arch==arch and file.kind=='archive'
                        and file.filename==release.version..'.linux-'..arch..'.tar.gz'
                        and type(file.sha256)=='string' and #file.sha256==64 and not file.sha256:find('[^a-f0-9]') then
                        chosen,asset=release.version,file;break
                    end
                end
            end
            if asset then break end
        end
        assert(asset,'No official stable Go archive for Linux/'..arch)
        local parent=join(home,'sdk');vim.fn.mkdir(parent,'p')
        local target=join(parent,chosen)
        if uv.fs_lstat(target) then
            assert(ready(join(target,'bin')),'Existing SDK directory preserved; choose or repair it: '..target)
            finish(join(target,'bin'),true);return
        end
        stage=join(parent,'.fride-go-'..uv.os_getpid()..'-'..uv.hrtime());assert(uv.fs_mkdir(stage,448))
        local archive=join(stage,asset.filename)
        print('Downloading official '..chosen..' to '..target);io.stdout:flush()
        fetch('https://go.dev/dl/'..asset.filename,archive)
        local f=assert(io.open(archive,'rb'));local bytes=f:read('*a');f:close()
        assert(vim.fn.sha256(bytes)==asset.sha256,'Official Go SHA256 mismatch');bytes=nil
        -- GNU tar quotes non-ASCII names by default. Inspect literal archive
        -- paths, otherwise official Unicode test files look like backslashes.
        local names=run({'tar','--quoting-style=literal','-tzf',archive})
        for name in names:gmatch('[^\n]+') do
            assert((name=='go' or name:sub(1,3)=='go/') and not name:find('/%.%./') and not name:match('/%.%.$')
                and not name:find('[\\\r]'),'Invalid official archive path: '..vim.inspect(name))
        end
        run({'tar','--no-same-owner','-xzf',archive,'-C',stage})
        assert(ready(join(stage,'go/bin')),'Downloaded Go SDK failed its native version probe')
        assert(uv.fs_mkdir(target,448),'SDK target appeared during preparation; existing directory preserved')
        reserved=target
        assert(uv.fs_rename(join(stage,'go'),target));reserved=nil
        finish(join(target,'bin'),false)
    else
        local cargo=vim.env.CARGO_HOME
        if not cargo or cargo=='' then cargo=join(home,'.cargo') end
        local bin=join(cargo,'bin')
        if ready(bin) then finish(bin,true);return end
        local rustup=join(bin,'rustup'..suffix)
        if vim.fn.executable(rustup)~=1 then
            assert(not windows,'Install rustup through WinGet before preparing its active toolchain')
            local root=vim.env.TMPDIR
            if not root or root=='' then root=uv.os_tmpdir() end
            stage=join(root,'fride-rustup-'..uv.os_getpid()..'-'..uv.hrtime());assert(uv.fs_mkdir(stage,448))
            local script=join(stage,'rustup-init.sh');fetch('https://sh.rustup.rs',script)
            print('Installing native rustup with rustfmt/rust-src into ordinary Cargo/Rustup homes');io.stdout:flush()
            run({'/bin/sh',script,'-y','--no-modify-path','--profile','minimal','--default-toolchain','stable',
                '--component','rustfmt','--component','rust-src'},{timeout=900000})
        end
        if not ready(bin) then
            -- Native rustup selects the active project/default toolchain. A ready
            -- SDK has already returned above, so its compiler is never updated.
            run({rustup,'toolchain','install','--profile','minimal','--component','rustfmt',
                '--component','rust-src','--no-self-update'},{timeout=900000})
        end
        assert(vim.fn.executable(join(bin,'rustfmt'..suffix))==1,'rustfmt component missing')
        local sysroot=run({join(bin,'rustc'..suffix),'--print','sysroot'},{timeout=10000,env={RUSTUP_AUTO_INSTALL='0'}})
        assert(vim.fn.isdirectory(join(sysroot,'lib/rustlib/src/rust/library'))==1,'rust-src component missing')
        finish(bin,false)
    end
end,debug.traceback)
-- Only a newly created empty reservation and this worker's unique stage.
if reserved then uv.fs_rmdir(reserved) end
if stage then vim.fn.delete(stage,'rf') end
if not ok then io.stderr:write(tostring(why)..'\n');vim.cmd('cquit 1') end
