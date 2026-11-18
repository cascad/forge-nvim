-- Internal adapter: lets Python use the real Lua registry without parsing Lua.
local root,request,output=arg[1],arg[2],arg[3]
package.path=root..'/tests/lib/?.lua;'..package.path
local data=vim.json.decode(table.concat(vim.fn.readfile(request),'\n'))
local batch=require('batch_plan')
local plan=batch.select(dofile(root..'/tests/registry.lua'),batch.native_suites(root),data.mode,data.files,vim.fn.has('win32')==1)
assert(vim.fn.writefile(vim.split('return '..vim.inspect(plan.registry),'\n',{plain=true}),output)==0)
assert(loadfile(output)) -- A dry plan must also validate the generated registry.
io.stdout:write(vim.json.encode(plan))
