-- spec: IDE-BOOT-39. Explicit setup only, before Mason snapshots its environment.
local M={}
function M.resolve(options)
    options=options or {}
    local wanted={}
    if options.ids then
        for _,id in ipairs(options.ids) do wanted[id]=true end
    else
        for _,name in ipairs(require('forge.tool_catalog').mason()) do
            if name=='debugpy' then wanted.python=true end
            if vim.tbl_contains({'pyright','prettier','typescript-language-server','js-debug-adapter','bash-language-server'},name) then wanted.node=true end
        end
    end
    local selected,bins,seen={}, {}, {}
    local win=vim.fn.has('win32')==1
    local function key(path) path=vim.fs.normalize(path);return win and path:lower() or path end
    for _,kind in ipairs({'python','node'}) do
        if wanted[kind] then
            local paths=require('forge.tool_paths')
            local path,explicit=paths.override(kind,{global=kind=='python' and 'forge_python_path' or 'forge_node_executable',
                env=kind=='python' and 'FORGE_PYTHON_PATH' or 'FORGE_NODE_EXECUTABLE',scope=options.scope})
            if explicit then
                local entry=paths.current(kind)
                local function fail(message) error('Setup SDK '..kind..' ['..entry.source..']: '..message,0) end
                local bin=vim.fs.dirname(path)
                local names=kind=='node' and {win and 'node.exe' or 'node'}
                    or (win and {'python.exe','python3.exe'} or {'python3','python'})
                local native
                for _,name in ipairs(names) do if vim.fn.executable(bin..'/'..name)==1 then native=bin..'/'..name;break end end
                if not native or key(vim.uv.fs_realpath(native) or native)~=key(vim.uv.fs_realpath(path) or path) then
                    fail('Selected executable cannot be exposed by native '..kind..' commands in '..bin..
                        '. Choose a normal SDK/venv installation; no wrapper or PATH fallback was created.')
                end
                if kind=='node' then
                    local npm=bin..(win and '/npm.cmd' or '/npm')
                    if vim.fn.filereadable(npm)~=1 or not win and vim.fn.executable(npm)~=1 then
                        fail('npm not found beside selected Node: '..npm..'. Choose Node with npm.')
                    end
                end
                selected[kind]={path=path,command=native,source=entry.source,bin=bin,env=vim.empty_dict(),tools={[kind]=path}}
                if kind=='node' then selected[kind].tools.npm=bin..(win and '/npm.cmd' or '/npm') end
                if not seen[key(bin)] then seen[key(bin)]=true;bins[#bins+1]=bin end
            end
        end
    end
    return selected,bins
end
function M.prepare(options)
    if vim.g.forge_setup_sdk_report then return vim.g.forge_setup_sdk_report end
    options=options or {}
    local selected,bins=M.resolve(options)
    -- A late PATH edit cannot update Mason's captured initial_environ.
    if #bins>0 then
        assert(not package.loaded['mason-core.process'],'Selected SDK setup must run before Mason; rerun the explicit installer/setup entrypoint.')
        bins[#bins+1]=vim.env.PATH or '';vim.env.PATH=table.concat(bins,vim.fn.has('win32')==1 and ';' or ':')
    end
    local kinds={}
    for _,kind in ipairs({'go','rust'}) do
        if require('forge.install_profile').prepared(kind) then kinds[#kinds+1]=kind end
    end
    local report={phase='pre-mason',selected=selected,scope=options.scope,sdk_kinds=kinds}
    vim.g.forge_setup_sdk_report=report
    return report
end
return M
