-- IDE-BOOT-51. Prompt policy only; SDK/tool choices keep their existing files.
local M={}
local known={go=true,rust=true,python=true,node=true,bash=true,sql=true}
function M.files(root)
    root=require('forge.tool_paths').root(root)
    return {user=vim.fs.joinpath(vim.fn.stdpath('config'),'languages.json'),project=vim.fs.joinpath(root,'.fride/languages.json')}
end
local function read(file)
    local stat,why,code=vim.uv.fs_stat(file)
    if not stat then
        if code=='ENOENT' then return {version=1,prompts=vim.empty_dict()} end
        error('Language settings ['..file..']: '..tostring(why),0)
    end
    assert(stat.type=='file' and stat.size<=65536,'Language settings must be a file <=64KiB: '..file)
    local handle=assert(io.open(file,'rb'));local raw=handle:read('*a');handle:close()
    local data=vim.json.decode(raw)
    assert(type(data)=='table' and data.version==1 and type(data.prompts)=='table','Expected version=1, prompts object: '..file)
    for kind,value in pairs(data.prompts) do
        assert(known[kind] and (value=='ask' or value=='manual'),'Invalid language prompt policy: '..file)
    end
    return data
end
function M.get(kind,root)
    assert(known[kind],'Unknown language')
    local files=M.files(root)
    for _,scope in ipairs({'project','user'}) do
        local data=read(files[scope]);local value=data.prompts[kind]
        if value then return {value=value,scope=scope,file=files[scope],source=scope..': '..files[scope]} end
    end
    return {value='ask',scope='default',source='по умолчанию'}
end
function M.set(kind,value,scope,root)
    assert(known[kind] and (value==nil or value=='ask' or value=='manual'),'Invalid language policy')
    assert(scope=='project' or scope=='user','Expected project/user scope')
    local file=M.files(root)[scope];local data=read(file)
    data.prompts[kind]=value
    if vim.tbl_isempty(data.prompts) then data.prompts=vim.empty_dict() end
    vim.fn.mkdir(vim.fs.dirname(file),'p')
    local temporary=file..'.'..vim.uv.os_getpid()..'.tmp'
    local ok,why=pcall(function()
        local handle=assert(io.open(temporary,'wb'));assert(handle:write(vim.json.encode(data)..'\n'));assert(handle:close())
        assert(vim.uv.fs_rename(temporary,file))
    end)
    if not ok then vim.uv.fs_unlink(temporary);error(why,0) end
    return file
end
return M
