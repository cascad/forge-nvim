-- spec: IDE-BOOT-40. Verified Core, no user init/plugins and no SDK CLI calls.
local source,runtime,request,output=unpack(arg)
local function read(path)
    local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return bytes
end
local ok,why=pcall(function()
    dofile(vim.fs.joinpath(source,'scripts/runtime-core.lua')).validate(source,runtime)
    vim.opt.rtp:prepend(vim.fs.joinpath(source,'nvim_forge'))
    local ids=vim.json.decode(read(request))
    local report={schema=1,selections=vim.empty_dict(),errors=vim.empty_dict()}
    for _,id in ipairs(ids) do
        local resolved,value=pcall(function()
            if id=='go' or id=='rust' then return require('forge.sdk').selection(id,nil,{scope='user'}) end
            assert(id=='python' or id=='node','Unknown native SDK: '..tostring(id))
            local selected=require('forge.setup_sdks').resolve({ids={id},scope='user'})
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
