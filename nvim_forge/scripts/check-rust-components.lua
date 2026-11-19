-- IDE-BOOT-50. Explicit read-only SDK check, used by native preparation and UI.
local rustc,output,scope=unpack(arg)
local config=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.rtp:prepend(config)
local data=require('forge.rust_components').inspect(rustc~='' and rustc or nil,scope or 'project')
local f=assert(io.open(output,'wb'));assert(f:write(vim.json.encode(data)..'\n'));assert(f:close())
