-- Real lookup observer: records calls without changing filesystem results.
local repo,source,project,fixture,class,title,out=unpack(arg)
package.path=source..'/?.lua;'..repo..'/tests/lib/?.lua;'..package.path
assert(vim.fn.writefile({},out..'/lookups.jsonl')==0)
local original=vim.fn.exepath
vim.fn.exepath=function(name)
  assert(vim.fn.writefile({vim.json.encode({name=name})},out..'/lookups.jsonl','a')==0)
  return original(name)
end
local helper=require('python_case')
local actual=debug.getinfo(helper.run,'S').source:sub(2)
assert(vim.uv.fs_copyfile(actual,out..'/python_case.lua'))
assert(vim.fn.writefile({vim.json.encode({source=actual,filter=vim.env.FORGE_TEST_ID,
  executable=vim.v.progpath,version=tostring(vim.version()),cwd=vim.fn.getcwd()})},out..'/driver-ready.json')==0)
helper.run(project,fixture,class,title)
