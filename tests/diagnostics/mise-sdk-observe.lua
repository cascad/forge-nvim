-- spec: IDE-BOOT-53. Real mise shim and Python environments; no SDK downloads.
local root,project_a,project_b,shim,prefix,output=unpack(arg)
vim.opt.rtp:prepend(root..'/nvim_forge')
require('forge.tool_paths').save('python',shim,'user',project_a)
local languages=require('forge.languages')
local function check(directory)
 local result
 languages.recheck('python',directory,function(state)result=state end)
 assert(vim.wait(15000,function()return result~=nil end,10),'SDK check timeout: '..directory)
 for _,sdk in ipairs(result.sdks)do if sdk.kind=='python' then return sdk end end
 error('Python SDK state missing')
end
local first=check(project_a);assert(first.ready,first.error)
local broken=check(project_b);assert(not broken.ready and broken.error,'Missing SDK should be reported')
local retained
for _,sdk in ipairs(languages.status('python',project_a).sdks)do if sdk.kind=='python' then retained=sdk end end
assert(retained and retained.ready,'Another project poisoned the SDK cache')
local selected,why,finished
require('forge.runtime_sdk').probe('python',shim,function(sdk,err)selected=sdk;why=err;finished=true end,project_a)
assert(vim.wait(15000,function()return finished end,10),'Prefix probe timeout')
assert(selected,why)
assert(vim.uv.fs_realpath(selected.prefix)==vim.uv.fs_realpath(prefix),'Wrong project interpreter: '..tostring(selected.prefix))
vim.fn.writefile({vim.json.encode({schema=1,ready=true,first=first,broken=broken,retained=retained,prefix=selected.prefix,cache_keys=vim.tbl_keys(languages.versions)})},output)
print('Native mise project context/cache/readonly SDK PASS')
