-- spec: IDE-BOOT-40. Verified Core, no user init/plugins and no SDK CLI calls.
local source,runtime,request,output,config,scope=unpack(arg)
-- Reading SDK configuration must not install versions through environment managers.
vim.env.MISE_AUTO_INSTALL='false';vim.env.MISE_EXEC_AUTO_INSTALL='false';vim.env.MISE_NOT_FOUND_AUTO_INSTALL='false'
scope=scope or 'user'
local function read(path)
    local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return bytes
end
local ok,why=pcall(function()
    dofile(vim.fs.joinpath(source,'scripts/runtime-core.lua')).validate(source,runtime)
    vim.opt.rtp:prepend(config or vim.fs.joinpath(source,'nvim_forge'))
    local ids=vim.json.decode(read(request))
    local report={schema=1,selections=vim.empty_dict(),errors=vim.empty_dict()}
    if scope=='project' then report.cwd=vim.fn.getcwd() end
    for _,id in ipairs(ids) do
        local resolved,value=pcall(function()
            if id=='cargo-nextest' then
                local path=require('forge.nextest').executable(nil,{scope=scope})
                if not path then return end
                return {tools={['cargo-nextest']=path},bin=vim.fs.dirname(path),env=vim.empty_dict(),
                    source=require('forge.tool_paths').current('cargo-nextest').source}
            end
            if id=='go' or id=='rust' then return require('forge.sdk').selection(id,nil,{scope=scope}) end
            assert(id=='python' or id=='node','Unknown native SDK: '..tostring(id))
            local selected=require('forge.setup_sdks').resolve({ids={id},scope=scope})
            return selected[id]
        end)
        if not resolved then report.errors[id]=tostring(value)
        elseif value then
            report.selections[id]={tools=value.tools,bin=value.bin,env=value.env,source=value.source}
        end
    end
    local f=assert(io.open(output,'wb'));assert(f:write(vim.json.encode(report)));assert(f:close())
end)
if not ok then io.stderr:write(tostring(why)..'\n');vim.cmd('cquit 1') end
