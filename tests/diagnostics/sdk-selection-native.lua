-- Observer only: native tools still execute unchanged.
_G.forge_sdk_spawns={}
local spawn=vim.uv.spawn
local notify=vim.notify
vim.notify=function(message,level,options)
    if (level or 2)>=vim.log.levels.ERROR then
        vim.fn.writefile({vim.json.encode({message=tostring(message),level=level})},vim.env.FORGE_SESSION_PROBE..'/sdk-errors.jsonl','a')
    end
    return notify(message,level,options)
end
vim.uv.spawn=function(command,options,...)
    _G.forge_sdk_spawns[#_G.forge_sdk_spawns+1]={cmd=command,args=(options or {}).args,
        go=vim.uv.os_getenv('GOROOT'),rust=vim.uv.os_getenv('RUSTUP_TOOLCHAIN'),
        rustc=vim.uv.os_getenv('RUSTC'),cargo=vim.uv.os_getenv('CARGO')}
    return spawn(command,options,...)
end
