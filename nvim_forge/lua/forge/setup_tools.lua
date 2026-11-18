-- spec: IDE-BOOT-45. Explicit setup of keys already consumed by the runtime.
local M={}
local executables={gopls=true,gofumpt=true,golines=true,['rust-analyzer']=true,
    codelldb=true,sqruff=true,delve='dlv'}
local scripts={prettier=true,['typescript-language-server']=true,
    ['bash-language-server']=true,['js-debug-adapter']=true,['bash-debug-adapter']=true}

local function outside_replacement(path,source)
    local target=vim.env.FORGE_INSTALL_TARGET
    if not target or target=='' then return end
    local function normalize(value)
        value=vim.fs.normalize(vim.uv.fs_realpath(value) or vim.fn.fnamemodify(value,':p')):gsub('/+$','')
        return vim.fn.has('win32')==1 and value:lower() or value
    end
    local actual=normalize(path)
    for _,dir in ipairs({'bin','runtime','config'}) do
        local replaced=normalize(vim.fs.joinpath(target,dir))
        assert(actual~=replaced and actual:sub(1,#replaced+1)~=replaced..'/',
            'Setup tool ['..source..'] is inside replaced kit '..dir..': '..path..'. Choose an external installation.')
    end
end

function M.external(name)
    local key=executables[name]
    if key==true then key=name end
    local kind='executable'
    if scripts[name] then key=name;kind='file' end
    if not key then return end
    local paths=require('forge.tool_paths')
    local path,explicit=paths.override(key,{scope='user',kind=kind})
    if not explicit then return end
    local entry=paths.current(key)
    outside_replacement(path,entry.source)
    local command={path}
    if kind=='file' then
        local node,chosen=paths.override('node',{scope='user',global='forge_node_executable',env='FORGE_NODE_EXECUTABLE'})
        if not chosen then node=vim.fn.exepath('node') end
        assert(node and node~='','Setup tool '..name..' ['..entry.source..'] requires Node; choose an existing Node SDK.')
        command={node,path}
    end
    return {name=name,key=key,path=path,kind=kind,source=entry.source,command=command}
end

function M.plan(names)
    local plan={mason={},external={}}
    for _,name in ipairs(names) do
        local entry=M.external(name)
        if entry then plan.external[#plan.external+1]=entry else plan.mason[#plan.mason+1]=name end
    end
    return plan
end

function M.check(entries)
    for _,entry in ipairs(entries) do
        local current=M.external(entry.name)
        assert(current and current.path==entry.path,'Setup tool selection changed: '..entry.name..'; rerun explicit setup.')
    end
    return {external=#entries}
end
return M
